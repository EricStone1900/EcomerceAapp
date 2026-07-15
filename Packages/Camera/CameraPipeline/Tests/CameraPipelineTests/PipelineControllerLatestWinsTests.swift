// 见 PipelineController.swift 顶部注释：Metal 协议类型未标注 Sendable，用 @preconcurrency 处理。
@preconcurrency import Metal
import Testing

@testable import CameraPipeline

private actor AnalysisRecorder {
    private(set) var completedIDs: [PluginID] = []
    private(set) var cancelledIDs: [PluginID] = []

    func recordCompleted(_ id: PluginID) {
        completedIDs.append(id)
    }

    func recordCancelled(_ id: PluginID) {
        cancelledIDs.append(id)
    }
}

private struct SlowAnalyzer: FrameAnalyzer {
    let id: PluginID
    let preferredFPS = 1
    let delayNanoseconds: UInt64
    let recorder: AnalysisRecorder

    func analyze(_ frame: Frame) async -> [Annotation] {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        if Task.isCancelled {
            await recorder.recordCancelled(id)
        } else {
            await recorder.recordCompleted(id)
        }
        return []
    }
}

private func makeTestRenderArgs() throws -> (MTLTexture, RenderContext) {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false
    )
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let commandQueue = try #require(device.makeCommandQueue())
    let commandBuffer = try #require(commandQueue.makeCommandBuffer())
    return (texture, RenderContext(device: device, commandBuffer: commandBuffer))
}

@Suite("PipelineController latest-frame-wins scheduling")
struct PipelineControllerLatestWinsTests {

    @Test("a new frame cancels the in-flight analysis task instead of queueing it")
    func newFrameCancelsPreviousAnalysis() async throws {
        let recorder = AnalysisRecorder()
        let controller = PipelineController()
        let analyzer = SlowAnalyzer(id: PluginID("slow"), delayNanoseconds: 200_000_000, recorder: recorder)
        await controller.setAnalyzers([analyzer])

        let (texture, context) = try makeTestRenderArgs()
        let frame = makeTestFrame()

        await controller.consume(frame, texture: texture, context: context)
        try await Task.sleep(nanoseconds: 20_000_000)
        await controller.consume(frame, texture: texture, context: context)

        try await Task.sleep(nanoseconds: 400_000_000)

        let cancelled = await recorder.cancelledIDs
        let completed = await recorder.completedIDs
        #expect(cancelled == [PluginID("slow")])
        #expect(completed == [PluginID("slow")])
    }

    @Test("renderedFrames receives a texture even with no analyzers configured")
    func renderedFramesYieldsWithEmptyAnalyzers() async throws {
        let controller = PipelineController()
        let (texture, context) = try makeTestRenderArgs()

        var iterator = controller.renderedFrames.makeAsyncIterator()
        await controller.consume(makeTestFrame(), texture: texture, context: context)

        let received = await iterator.next()
        #expect(received != nil)
    }

    @Test("annotations carries the upright image size of the frame that produced it")
    func annotationsCarriesUprightImageSize() async throws {
        let recorder = AnalysisRecorder()
        let controller = PipelineController()
        let analyzer = SlowAnalyzer(id: PluginID("slow"), delayNanoseconds: 1_000_000, recorder: recorder)
        await controller.setAnalyzers([analyzer])

        let (texture, context) = try makeTestRenderArgs()
        // .right 是 90 度旋转，摆正后宽高互换：400x300 的传感器画面转正后应该是 300x400。
        let frame = makeTestFrame(width: 400, height: 300, orientation: .right)

        var iterator = controller.annotations.makeAsyncIterator()
        await controller.consume(frame, texture: texture, context: context)

        let batch = await iterator.next()
        #expect(batch?.uprightImageSize == CGSize(width: 300, height: 400))
    }
}

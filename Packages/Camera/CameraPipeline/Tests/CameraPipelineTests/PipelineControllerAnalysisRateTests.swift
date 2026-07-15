// 见 PipelineController.swift 顶部注释：Metal 协议类型未标注 Sendable，用 @preconcurrency 处理。
@preconcurrency import Metal
import Testing

@testable import CameraPipeline

private actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

private struct CountingAnalyzer: FrameAnalyzer {
    let id = PluginID("counting")
    let preferredFPS = 30
    let counter: CallCounter

    func analyze(_ frame: Frame) async -> [Annotation] {
        await counter.increment()
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

/// 每组测试都在每次"真正触发分析"（hit）之后从 annotations 流里等一个值，再发下一批帧——
/// 不这样做的话，连续两次 hit 之间会有 PipelineController.consume 里
/// `inFlightAnalysisTask?.cancel()` 那句提前取消上一个 hit 的分析任务的真实竞争窗口
/// （consume 本身不等分析任务跑完就返回），测试会偶发不稳定。等 annotations 流吐一个值，
/// 就保证了上一个 hit 已经真正跑完，不会跟下一个 hit 抢同一个 inFlightAnalysisTask。
@Suite("PipelineController analysis rate divisor (thermal 降频用)")
struct PipelineControllerAnalysisRateTests {

    @Test("divisor N only runs the analyzer on every Nth frame")
    func divisorSkipsFrames() async throws {
        let counter = CallCounter()
        let controller = PipelineController()
        await controller.setAnalyzers([CountingAnalyzer(counter: counter)])
        await controller.setAnalysisRateDivisor(3)

        let (texture, context) = try makeTestRenderArgs()
        let frame = makeTestFrame()
        var iterator = controller.annotations.makeAsyncIterator()

        for _ in 0..<2 {
            await controller.consume(frame, texture: texture, context: context) // 1/3, skip
            await controller.consume(frame, texture: texture, context: context) // 2/3, skip
            await controller.consume(frame, texture: texture, context: context) // 3/3, hit
            _ = await iterator.next()
        }

        #expect(await counter.count == 2)
    }

    @Test("divisor 1 (the default) runs the analyzer on every frame")
    func divisorOneRunsEveryFrame() async throws {
        let counter = CallCounter()
        let controller = PipelineController()
        await controller.setAnalyzers([CountingAnalyzer(counter: counter)])

        let (texture, context) = try makeTestRenderArgs()
        let frame = makeTestFrame()
        var iterator = controller.annotations.makeAsyncIterator()

        for _ in 0..<3 {
            await controller.consume(frame, texture: texture, context: context)
            _ = await iterator.next()
        }

        #expect(await counter.count == 3)
    }

    @Test("setAnalysisRateDivisor resets the internal frame counter")
    func settingDivisorResetsCounter() async throws {
        let counter = CallCounter()
        let controller = PipelineController()
        await controller.setAnalyzers([CountingAnalyzer(counter: counter)])
        await controller.setAnalysisRateDivisor(3)

        let (texture, context) = try makeTestRenderArgs()
        let frame = makeTestFrame()
        var iterator = controller.annotations.makeAsyncIterator()

        await controller.consume(frame, texture: texture, context: context) // 1/3, skip
        await controller.consume(frame, texture: texture, context: context) // 2/3, skip
        await controller.setAnalysisRateDivisor(1) // 重置 frameCounter 并把 divisor 降回 1
        await controller.consume(frame, texture: texture, context: context) // 1/1, hit
        _ = await iterator.next()

        #expect(await counter.count == 1)
    }
}

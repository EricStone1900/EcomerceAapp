import CoreVideo
import Foundation
@preconcurrency import Metal
import Testing

import CameraPipeline
@testable import CameraFeature

private func makeTestFrame() -> Frame {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, 1, 1, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    return Frame(
        pixelBuffer: pixelBuffer!, timestamp: .zero, orientation: .up,
        cameraMetadata: FrameMetadata(iso: 100, shutterDuration: .zero, lensPosition: 0, intrinsics: nil)
    )
}

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
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let commandQueue = try #require(device.makeCommandQueue())
    let commandBuffer = try #require(commandQueue.makeCommandBuffer())
    return (texture, RenderContext(device: device, commandBuffer: commandBuffer))
}

@Suite("ThermalPolicyUseCase.handle")
struct ThermalPolicyUseCaseTests {

    @Test(".critical clears the analyzer list and signals the caller to force passthrough")
    func criticalClearsAnalyzersAndSignalsPassthrough() async throws {
        let pipeline = PipelineController()
        let counter = CallCounter()
        await pipeline.setAnalyzers([CountingAnalyzer(counter: counter)])
        let useCase = ThermalPolicyUseCase(pipeline: pipeline)

        let shouldForcePassthrough = await useCase.handle(.critical)

        #expect(shouldForcePassthrough)

        // 分析链真的被清空了：PipelineController.consume 里 "guard !analyzers.isEmpty else { return }"
        // 在 analyzers 为空时同步返回、根本不会 spawn 分析 Task——所以这里不需要等待或竞态，
        // await 一结束就能确定性地检查 counter 有没有被增加过。
        let (texture, context) = try makeTestRenderArgs()
        await pipeline.consume(makeTestFrame(), texture: texture, context: context)

        #expect(await counter.count == 0)
    }

    @Test(".serious lowers the analysis rate without clearing analyzers, and doesn't force passthrough")
    func seriousLowersRateWithoutClearingAnalyzers() async throws {
        let pipeline = PipelineController()
        let counter = CallCounter()
        await pipeline.setAnalyzers([CountingAnalyzer(counter: counter)])
        let useCase = ThermalPolicyUseCase(pipeline: pipeline, seriousStateDivisor: 2)

        let shouldForcePassthrough = await useCase.handle(.serious)

        #expect(shouldForcePassthrough == false)

        let (texture, context) = try makeTestRenderArgs()
        var iterator = pipeline.annotations.makeAsyncIterator()
        await pipeline.consume(makeTestFrame(), texture: texture, context: context) // 1/2, skip
        await pipeline.consume(makeTestFrame(), texture: texture, context: context) // 2/2, hit
        _ = await iterator.next()

        #expect(await counter.count == 1)
    }

    @Test(".nominal resets the analysis rate divisor back to 1")
    func nominalResetsRateDivisor() async throws {
        let pipeline = PipelineController()
        let counter = CallCounter()
        await pipeline.setAnalyzers([CountingAnalyzer(counter: counter)])
        let useCase = ThermalPolicyUseCase(pipeline: pipeline, seriousStateDivisor: 3)

        _ = await useCase.handle(.serious)
        _ = await useCase.handle(.nominal)

        let (texture, context) = try makeTestRenderArgs()
        var iterator = pipeline.annotations.makeAsyncIterator()
        await pipeline.consume(makeTestFrame(), texture: texture, context: context) // divisor 已经回到 1，应该立刻 hit
        _ = await iterator.next()

        #expect(await counter.count == 1)
    }
}

@Suite("ThermalState.init(systemThermalState:)")
struct ThermalStateSystemMappingTests {

    @Test("maps every ProcessInfo.ThermalState case to its corresponding ThermalState")
    func mapsAllCases() {
        #expect(ThermalState(systemThermalState: .nominal) == .nominal)
        #expect(ThermalState(systemThermalState: .fair) == .fair)
        #expect(ThermalState(systemThermalState: .serious) == .serious)
        #expect(ThermalState(systemThermalState: .critical) == .critical)
    }
}

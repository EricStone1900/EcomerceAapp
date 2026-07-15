// 见 CameraPipelineBridge.swift 顶部注释：Metal 协议类型未标注 Sendable，用 @preconcurrency 处理。
@preconcurrency import Metal
import AVFoundation
import CoreMedia
import CoreVideo
import Testing

import CameraCore
import CameraPipeline
import Shared
@testable import CameraFeature

private actor FakeFrameCameraSource: CameraSourceProtocol {

    nonisolated let frames: AsyncStream<CameraCore.Frame>
    nonisolated let capability: AsyncStream<DeviceCapability> = AsyncStream { _ in }
    nonisolated let interruptions: AsyncStream<InterruptionEvent> = AsyncStream { _ in }
    nonisolated(unsafe) let previewLayer = AVCaptureVideoPreviewLayer()

    private let frameContinuation: AsyncStream<CameraCore.Frame>.Continuation

    init() {
        var continuation: AsyncStream<CameraCore.Frame>.Continuation!
        frames = AsyncStream { continuation = $0 }
        frameContinuation = continuation
    }

    func apply(_ control: CameraControl) async throws {}

    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult {
        throw CameraError.captureFailed(underlying: nil)
    }

    func currentExposureMetadata() -> CaptureExposureMetadata {
        CaptureExposureMetadata(iso: 100, shutterDuration: CMTime(value: 1, timescale: 60), lensPosition: 0.5)
    }

    func emit(_ frame: CameraCore.Frame) {
        frameContinuation.yield(frame)
    }
}

private func makeBGRAPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
    // CVMetalTextureCache 只能绑定 IOSurface-backed 的 CVPixelBuffer——真机摄像头输出的
    // buffer 本来就是 IOSurface-backed（不需要特殊处理），但测试里手工 CVPixelBufferCreate
    // 默认不带 IOSurface，必须显式传 kCVPixelBufferIOSurfacePropertiesKey，否则
    // CVMetalTextureCacheCreateTextureFromImage 会静默失败（返回非 success 状态，不抛错、不崩溃），
    // 导致 makeTexture 返回 nil，bridge 直接丢帧——第一版测试因为漏了这个属性挂死在
    // await iterator.next()，一直等一个永远不会到来的值。
    let attributes: [CFString: Any] = [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ]
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer
    )
    #expect(status == kCVReturnSuccess)
    return try #require(pixelBuffer)
}

@Suite("CameraPipelineBridge")
struct CameraPipelineBridgeTests {

    @Test("a real CVPixelBuffer flows through CVMetalTextureCache into PipelineController.renderedFrames")
    func frameFlowsIntoPipeline() async throws {
        let source = FakeFrameCameraSource()
        let pipeline = PipelineController()
        let bridge = CameraPipelineBridge(cameraSource: source, pipelineController: pipeline)

        var iterator = pipeline.renderedFrames.makeAsyncIterator()

        await bridge.start()
        let pixelBuffer = try makeBGRAPixelBuffer(width: 64, height: 48)
        await source.emit(CameraCore.Frame(pixelBuffer: pixelBuffer, timestamp: .zero))

        let texture = await iterator.next()
        let received = try #require(texture)
        #expect(received.width == 64)
        #expect(received.height == 48)
        #expect(received.pixelFormat == .bgra8Unorm)

        await bridge.stop()
    }

    @Test("start() is idempotent and does not double-subscribe the frames stream")
    func startIsIdempotent() async throws {
        let source = FakeFrameCameraSource()
        let pipeline = PipelineController()
        let bridge = CameraPipelineBridge(cameraSource: source, pipelineController: pipeline)

        await bridge.start()
        await bridge.start()

        var iterator = pipeline.renderedFrames.makeAsyncIterator()
        let pixelBuffer = try makeBGRAPixelBuffer(width: 32, height: 32)
        await source.emit(CameraCore.Frame(pixelBuffer: pixelBuffer, timestamp: .zero))

        let texture = await iterator.next()
        #expect(texture != nil)

        await bridge.stop()
    }
}

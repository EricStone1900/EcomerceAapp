import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import ImageIO
import Testing
import UniformTypeIdentifiers

import CameraCore
import CameraPipeline
import Shared
@testable import CameraFeature

private actor StubCameraSource: CameraSourceProtocol {

    let result: PhotoCaptureResult

    nonisolated let frames: AsyncStream<CameraCore.Frame> = AsyncStream { _ in }
    nonisolated let capability: AsyncStream<DeviceCapability> = AsyncStream { _ in }
    nonisolated let interruptions: AsyncStream<InterruptionEvent> = AsyncStream { _ in }
    nonisolated(unsafe) let previewLayer = AVCaptureVideoPreviewLayer()

    init(result: PhotoCaptureResult) {
        self.result = result
    }

    func apply(_ control: CameraControl) async throws {}

    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult {
        result
    }

    func currentExposureMetadata() -> CaptureExposureMetadata {
        CaptureExposureMetadata(iso: 0, shutterDuration: .zero, lensPosition: 0)
    }
}

/// 造一张真实的纯色 HEIC 文件写到临时目录，用来当 "raw.processedFileURL" 的替身——
/// DocumentCaptureUseCase 现在会真的用 CIImage(contentsOf:) 读它，假路径会直接读取失败。
private func makeTestHEICFile(width: Int, height: Int) throws -> URL {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())

    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("heic")
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return url
}

@Suite("DocumentCaptureUseCase")
struct DocumentCaptureUseCaseTests {

    private static func makeExpectedResult() throws -> PhotoCaptureResult {
        PhotoCaptureResult(
            processedFileURL: try makeTestHEICFile(width: 400, height: 300),
            rawFileURL: URL(fileURLWithPath: "/tmp/raw.dng")
        )
    }

    @Test("no detection result degrades to a plain photo capture")
    func nilQuadDegradesToPlainCapture() async throws {
        let expected = try Self.makeExpectedResult()
        let useCase = DocumentCaptureUseCase(
            cameraSource: StubCameraSource(result: expected),
            pipeline: PipelineController()
        )

        let result = try await useCase.capture(latestQuad: nil, targetSize: CGSize(width: 100, height: 100))

        #expect(result.processedFileURL == expected.processedFileURL)
        #expect(result.rawFileURL == expected.rawFileURL)
    }

    @Test("a non-quad annotation also degrades to a plain photo capture")
    func nonQuadAnnotationDegradesToPlainCapture() async throws {
        let expected = try Self.makeExpectedResult()
        let useCase = DocumentCaptureUseCase(
            cameraSource: StubCameraSource(result: expected),
            pipeline: PipelineController()
        )

        let result = try await useCase.capture(
            latestQuad: .horizon(angle: 1.5),
            targetSize: CGSize(width: 100, height: 100)
        )

        #expect(result.processedFileURL == expected.processedFileURL)
    }

    @Test("a quad annotation with 4 corners produces a new cropped HEIC file of exactly targetSize")
    func quadAnnotationProducesCroppedFileOfTargetSize() async throws {
        let expected = try Self.makeExpectedResult()
        let useCase = DocumentCaptureUseCase(
            cameraSource: StubCameraSource(result: expected),
            pipeline: PipelineController()
        )
        // 归一化坐标（左下原点），[topLeft, topRight, bottomRight, bottomLeft]，一个比整张图稍小的四边形。
        let quad = Annotation.quad(
            id: UUID(),
            corners: [
                CGPoint(x: 0.1, y: 0.9), CGPoint(x: 0.9, y: 0.9),
                CGPoint(x: 0.9, y: 0.1), CGPoint(x: 0.1, y: 0.1),
            ],
            confidence: 0.9
        )
        let targetSize = CGSize(width: 200, height: 300)

        let result = try await useCase.capture(latestQuad: quad, targetSize: targetSize)

        // 输出是一个新文件（不是原图），原始 DNG 保持不变。
        #expect(result.processedFileURL != expected.processedFileURL)
        #expect(result.rawFileURL == expected.rawFileURL)
        #expect(FileManager.default.fileExists(atPath: result.processedFileURL.path))

        let source = try #require(CGImageSourceCreateWithURL(result.processedFileURL as CFURL, nil))
        let cgImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(cgImage.width == Int(targetSize.width))
        #expect(cgImage.height == Int(targetSize.height))
    }

    @Test("a quad with fewer than 4 corners degrades to a plain photo capture")
    func degenerateQuadDegradesToPlainCapture() async throws {
        let expected = try Self.makeExpectedResult()
        let useCase = DocumentCaptureUseCase(
            cameraSource: StubCameraSource(result: expected),
            pipeline: PipelineController()
        )
        let quad = Annotation.quad(id: UUID(), corners: [CGPoint(x: 0.1, y: 0.1)], confidence: 0.9)

        let result = try await useCase.capture(latestQuad: quad, targetSize: CGSize(width: 100, height: 100))

        #expect(result.processedFileURL == expected.processedFileURL)
    }
}

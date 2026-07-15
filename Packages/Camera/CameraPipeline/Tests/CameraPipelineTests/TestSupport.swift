import CoreMedia
import CoreVideo
import ImageIO

@testable import CameraPipeline

func makeTestFrame() -> Frame {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, 1, 1, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    return Frame(
        pixelBuffer: pixelBuffer!,
        timestamp: .zero,
        orientation: .up,
        cameraMetadata: FrameMetadata(iso: 100, shutterDuration: .zero, lensPosition: 0, intrinsics: nil)
    )
}

func makeTestFrame(width: Int, height: Int, orientation: CGImagePropertyOrientation) -> Frame {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    return Frame(
        pixelBuffer: pixelBuffer!,
        timestamp: .zero,
        orientation: orientation,
        cameraMetadata: FrameMetadata(iso: 100, shutterDuration: .zero, lensPosition: 0, intrinsics: nil)
    )
}

/// 造一个纯色 BGRA 测试帧，用来验证 HistogramAnalyzer 的统计结果是不是"真的算对了"，
/// 而不只是"产出了一个 .histogram case"。
func makeSolidColorFrame(width: Int, height: Int, blue: UInt8, green: UInt8, red: UInt8) -> Frame {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    let buffer = pixelBuffer!

    CVPixelBufferLockBaseAddress(buffer, [])
    let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    for row in 0..<height {
        for column in 0..<width {
            let offset = row * bytesPerRow + column * 4
            base[offset] = blue
            base[offset + 1] = green
            base[offset + 2] = red
            base[offset + 3] = 255
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])

    return Frame(
        pixelBuffer: buffer,
        timestamp: .zero,
        orientation: .up,
        cameraMetadata: FrameMetadata(iso: 100, shutterDuration: .zero, lensPosition: 0, intrinsics: nil)
    )
}

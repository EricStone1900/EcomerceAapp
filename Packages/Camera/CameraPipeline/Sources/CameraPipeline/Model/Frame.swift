import CoreGraphics
import CoreMedia
import CoreVideo
import ImageIO

/// 全 pipeline 统一货币。camera buffer 池仅 ~15 个，Frame 只 retain CVPixelBuffer，
/// 任何异步插件禁止持有 CMSampleBuffer。
public struct Frame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer   // IOSurface-backed
    public let timestamp: CMTime
    public let orientation: CGImagePropertyOrientation
    public let cameraMetadata: FrameMetadata

    public init(
        pixelBuffer: CVPixelBuffer,
        timestamp: CMTime,
        orientation: CGImagePropertyOrientation,
        cameraMetadata: FrameMetadata
    ) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.orientation = orientation
        self.cameraMetadata = cameraMetadata
    }

    /// pixelBuffer 是传感器原始宽高（后置摄像头横向安装，竖屏持机时通常是 width > height），
    /// 按 orientation 转正后才是"人眼看到的"宽高比——.left/.right（以及各自的 mirrored 变体）
    /// 是 90 度旋转，需要交换宽高；CoordinateConverter 用这个值算 aspect-fill 裁切偏移。
    public var uprightImageSize: CGSize {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        switch orientation {
        case .left, .right, .leftMirrored, .rightMirrored:
            return CGSize(width: height, height: width)
        case .up, .down, .upMirrored, .downMirrored:
            return CGSize(width: width, height: height)
        @unknown default:
            return CGSize(width: width, height: height)
        }
    }
}

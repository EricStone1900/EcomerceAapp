import AVFoundation
import CoreMedia
import simd

/// AVCaptureVideoDataOutputSampleBufferDelegate 的回调运行在 sessionQueue（非 actor 隔离域），
/// 不能直接触碰 CameraSession 的 actor-isolated 状态。这里只把 CMSampleBuffer 转成
/// CameraCore.Frame 后 yield 给 frameContinuation——AsyncStream.Continuation 本身是
/// Sendable，可以安全地跨隔离域直接调用，不需要额外跳回 actor。
final class FrameOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let continuation: AsyncStream<Frame>.Continuation

    init(continuation: AsyncStream<Frame>.Continuation) {
        self.continuation = continuation
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        continuation.yield(Frame(
            pixelBuffer: pixelBuffer, timestamp: timestamp, intrinsics: Self.intrinsics(from: sampleBuffer)
        ))
    }

    // 只有 CameraSession.configureOutputs() 开了 connection.isCameraIntrinsicMatrixDeliveryEnabled
    // 且设备真的支持时，这个 attachment 才会出现——不满足条件时正常返回 nil，不是错误，
    // 调用方（CameraPipelineBridge）本来就把 intrinsics 当 Optional 处理。
    // internal（非 private）是为了让单测能直接喂一个带 / 不带 attachment 的 CMSampleBuffer 验证提取
    // 逻辑本身，不需要在测试里构造一个真实的 AVCaptureConnection（那个在 session 外几乎没法造）。
    static func intrinsics(from sampleBuffer: CMSampleBuffer) -> simd_float3x3? {
        guard let data = CMGetAttachment(
            sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil
        ) as? Data else { return nil }
        return data.withUnsafeBytes { $0.load(as: matrix_float3x3.self) }
    }
}

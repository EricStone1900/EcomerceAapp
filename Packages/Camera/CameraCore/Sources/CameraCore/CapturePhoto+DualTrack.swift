@preconcurrency import AVFoundation
import Shared

/// CapturePhotoUseCase 双轨落盘的 Core 层支撑：DNG 原样保存（不 crop 不 filter），
/// 并行产出 HEIF；EXIF 写入拍摄参数/镜头/GPS（由 AVCapturePhoto.fileDataRepresentation()
/// 自动带上系统采集到的元数据，不需要手动拼 EXIF 字典）。
extension CameraSession {

    func captureDualTrack(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult {
        let output = currentPhotoOutput
        // AVCapturePhotoOutput.capturePhoto(with:delegate:) 在没有已启用的 video connection 时
        // 会抛一个 Objective-C 异常（NSGenericException），Swift 的 try/catch 接不住，会直接
        // 让进程崩溃——必须在调用前用 connection(with:) 主动判断，转成可捕获的 CameraError。
        guard output.connection(with: .video) != nil else {
            throw CameraError.captureFailed(underlying: nil)
        }
        let settings = Self.makePhotoSettings(captureRAW: request.captureRAW, photoOutput: output)

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = DualTrackPhotoCaptureDelegate(continuation: continuation) { [weak self] finishedDelegate in
                Task { await self?.releasePhotoDelegate(finishedDelegate) }
            }
            retainPhotoDelegate(delegate)
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    /// AVCapturePhotoSettings(rawPixelFormatType:processedFormat:) 是 iOS-only API（macOS 摄像头
    /// 不支持 RAW 拍照），macOS host 上退回普通 HEVC 设置，保持本包可 swift build。
    private static func makePhotoSettings(captureRAW: Bool, photoOutput: AVCapturePhotoOutput) -> AVCapturePhotoSettings {
        #if os(iOS)
        guard captureRAW, let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else {
            return AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        return AVCapturePhotoSettings(
            rawPixelFormatType: rawFormat,
            processedFormat: [AVVideoCodecKey: AVVideoCodecType.hevc]
        )
        #else
        return AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        #endif
    }
}

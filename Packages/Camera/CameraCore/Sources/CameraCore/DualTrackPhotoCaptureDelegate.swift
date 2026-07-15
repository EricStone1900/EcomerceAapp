@preconcurrency import AVFoundation
import Foundation

import Shared

/// AVCapturePhotoOutput 的双轨（RAW+Processed）拍照委托。当 AVCapturePhotoSettings 同时请求
/// RAW 与 Processed 格式时，didFinishProcessingPhoto 会被回调两次（一次 RAW、一次 Processed），
/// 分别写盘为 DNG 与 HEIC；didFinishCaptureFor 是整个流程的终点，在这里 resume continuation。
///
/// AVCapturePhotoOutput.capturePhoto(with:delegate:) 不会强引用 delegate，调用方必须自己持有它
/// 直到 didFinishCaptureFor 触发——CameraSession 通过 onFinished 回调把自己从持有者集合里移除。
///
/// @unchecked Sendable：AVCapturePhotoOutput 保证同一次 capturePhoto 的所有委托回调都发生在
/// 同一个串行队列上，不会并发调用，rawFileURL/processedFileURL/capturedError 这几个可变属性
/// 实际上不存在并发写入——但类型系统看不出这一点，用 @unchecked 显式声明安全，避免每次跨
/// actor/Task 边界传递这个委托实例时都被 Swift 6 拦下来。
final class DualTrackPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {

    private let continuation: CheckedContinuation<PhotoCaptureResult, Error>
    // onFinished 把 self 当参数传回去，而不是让调用方提前捕获 self——调用方创建 delegate 时
    // 还没有一个已初始化的实例可以捕获，用 forward-declared var 反而会触发 Swift 6 的
    // "capture of var with non-Sendable type in an isolated closure" 报错。
    private let onFinished: @Sendable (DualTrackPhotoCaptureDelegate) -> Void

    private var rawFileURL: URL?
    private var processedFileURL: URL?
    private var capturedError: Error?

    init(continuation: CheckedContinuation<PhotoCaptureResult, Error>, onFinished: @escaping @Sendable (DualTrackPhotoCaptureDelegate) -> Void) {
        self.continuation = continuation
        self.onFinished = onFinished
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            capturedError = capturedError ?? error
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            capturedError = capturedError ?? CameraError.captureFailed(underlying: nil)
            return
        }
        // isRawPhoto 是 iOS-only API；macOS host 上没有真正的 RAW 拍照请求，统一当作 processed 处理，
        // 只是为了让本文件保持可 swift build，真实的 RAW/Processed 区分只在 iOS 上生效。
        #if os(iOS)
        let isRaw = photo.isRawPhoto
        #else
        let isRaw = false
        #endif
        do {
            let url = try Self.writeToTemporaryFile(data: data, pathExtension: isRaw ? "dng" : "heic")
            if isRaw {
                rawFileURL = url
            } else {
                processedFileURL = url
            }
        } catch {
            capturedError = capturedError ?? error
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        defer { onFinished(self) }

        if let failure = error ?? capturedError {
            continuation.resume(throwing: CameraError.captureFailed(underlying: failure))
            return
        }
        guard let processedFileURL else {
            continuation.resume(throwing: CameraError.captureFailed(underlying: nil))
            return
        }
        continuation.resume(returning: PhotoCaptureResult(processedFileURL: processedFileURL, rawFileURL: rawFileURL))
    }

    private static func writeToTemporaryFile(data: Data, pathExtension: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try data.write(to: url)
        return url
    }
}

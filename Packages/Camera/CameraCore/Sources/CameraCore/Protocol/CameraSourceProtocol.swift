import AVFoundation
import CoreMedia
import CoreVideo
import simd

/// Frame 在 Stage 2 CameraPipeline 里正式定义并扩展；Stage 1 先声明最小骨架，
/// 保证 CameraSourceProtocol 的 frames 流从第一天起就是稳定的公开接口。
public struct Frame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let timestamp: CMTime
    // 只有 CameraSession 开了 isCameraIntrinsicMatrixDeliveryEnabled 且设备支持时才有值，
    // 见 FrameOutputDelegate 里从 CMSampleBuffer attachment 提取的逻辑。
    public let intrinsics: simd_float3x3?

    public init(pixelBuffer: CVPixelBuffer, timestamp: CMTime, intrinsics: simd_float3x3? = nil) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.intrinsics = intrinsics
    }
}

/// 会话中断/恢复事件。CameraCore 只负责"发生了什么"，不做任何恢复策略决策——
/// 策略（例如 CameraSessionUseCase 收到 .ended 后自动 start()）属于 L4 业务层。
public enum InterruptionEvent: Sendable, Equatable {
    case began(reason: String)
    case ended
    case runtimeError(String)
}

/// L1 对外唯一出口，Pipeline（Stage 2 起）只依赖这个协议，不知道 AVFoundation 的存在。
public protocol CameraSourceProtocol: Actor {
    var frames: AsyncStream<Frame> { get }
    var capability: AsyncStream<DeviceCapability> { get }
    var interruptions: AsyncStream<InterruptionEvent> { get }
    var previewLayer: AVCaptureVideoPreviewLayer { get } // 仅 Passthrough 模式使用
    func apply(_ control: CameraControl) async throws
    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult
    /// 当前设备的瞬时曝光快照，供 L4 把 CameraCore.Frame 桥接成 CameraPipeline.Frame 时
    /// 填充 FrameMetadata。没有活跃设备时返回全零快照，不抛错（曝光信息属于"尽力而为"的
    /// 附加数据，不应该让整条 frame 流因为一次读取失败而中断）。
    func currentExposureMetadata() -> CaptureExposureMetadata
}

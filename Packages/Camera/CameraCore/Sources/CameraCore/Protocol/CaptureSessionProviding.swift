/// 真机实现: AVCaptureSession 包装；测试实现: 帧回放器（FramePlaybackProvider）。
/// Pipeline / Vision / ML 的所有单测通过注入录制帧序列完成，不依赖真机。
public protocol CaptureSessionProviding: Actor {
    func startRunning() async throws
    func stopRunning() async
    func configureOutputs() async throws
}

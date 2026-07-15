/// 测试桩：回放预先录制的帧序列，驱动 Pipeline / Vision / ML 单测，不依赖真机。
public actor FramePlaybackProvider: CaptureSessionProviding {

    private let recordedFrames: [Frame]

    public init(recordedFrames: [Frame]) {
        self.recordedFrames = recordedFrames
    }

    public func startRunning() async throws {}

    public func stopRunning() async {}

    public func configureOutputs() async throws {}
}

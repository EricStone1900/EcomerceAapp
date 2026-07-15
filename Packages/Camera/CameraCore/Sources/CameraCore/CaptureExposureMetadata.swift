import CoreMedia

/// L1 对外暴露的"当前曝光快照"，供 L4 CameraFeature 把 CameraCore.Frame 转成
/// CameraPipeline.Frame 时填充 FrameMetadata 用。只含瞬时可读的 AVCaptureDevice 属性，
/// 不含 intrinsics（相机内参需要在采集时从 CMSampleBuffer attachment 单独提取，
/// 属于后续按需实现的范围，见 avfoundation_capture_layer_followup.md）。
public struct CaptureExposureMetadata: Sendable {
    public let iso: Float
    public let shutterDuration: CMTime
    public let lensPosition: Float

    public init(iso: Float, shutterDuration: CMTime, lensPosition: Float) {
        self.iso = iso
        self.shutterDuration = shutterDuration
        self.lensPosition = lensPosition
    }
}

import CameraCore
import CameraFeature

/// 对应 `CameraFeature.CameraPreset.name`——Stage 4 没有引入专门的标识类型，Preset 就是按
/// name 存取的（`PluginRegistry`/`CapabilityValidator` 也都是这么处理的），这里保持一致。
public typealias PresetID = String

/// UI 订阅的单向状态。`manual` 是 Stage 4 落地的正式 `CameraFeature.ManualSettings`
/// （替换掉 Stage 1 的 `ManualSettingsPlaceholder` 占位类型），`activePreset` 记录当前生效的
/// Preset（`nil` 代表手动模式，不跟随任何 Preset）。UI 从第一天起就走"订阅 State + 发送 Action"
/// 单向数据流，不直接触碰 CameraCore。
public struct CameraViewState: Sendable {
    public var capability: DeviceCapability
    public var manual: ManualSettings
    public var annotations: [ScreenAnnotation]
    public var previewMode: PreviewMode
    public var activePreset: PresetID?

    public init(
        capability: DeviceCapability,
        manual: ManualSettings,
        annotations: [ScreenAnnotation] = [],
        previewMode: PreviewMode = .passthrough,
        activePreset: PresetID? = nil
    ) {
        self.capability = capability
        self.manual = manual
        self.annotations = annotations
        self.previewMode = previewMode
        self.activePreset = activePreset
    }
}

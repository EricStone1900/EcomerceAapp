import CameraCore
import CoreGraphics
import CoreMedia
import Shared

/// 补上 Stage 1 里注释掉的 `.applyPreset(PresetID)`——Stage 4 的 `CameraPreset` 落地后，
/// UI 层可以直接发送这个 Action 触发一次 Preset 应用（clamp + 装配渲染/分析链），
/// 不需要知道 `PresetUseCase`/`PluginRegistry` 这些具体类型的存在。
public enum CameraAction: Sendable {
    case setISO(Float), setShutter(CMTime), setEV(Float), setWB(WBGains)
    case focus(at: CGPoint), switchLens(LensType)
    case applyPreset(PresetID), capture
}

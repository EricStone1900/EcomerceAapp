import CameraCore

/// 把 Preset 里可能跨镜头非法的参数收敛到当前镜头真实支持的范围——例如 Document Preset 是在
/// 广角镜头上调好的 ISO 3200，切到支持范围更窄的超广角镜头后直接应用会被 AVFoundation 拒绝
/// （`CameraSession.apply` 里 `setExposureModeCustom` 对越界值的行为未定义）。校验失败在这里
/// 降级（clamp 到合法范围）而不是抛错——Preset 应用应该"尽量把效果做出来"，不应该因为某一个
/// 参数在新镜头上不兼容就让整个 Preset 应用失败。降级发生与否由调用方（`PresetUseCase`）
/// 对比 clamp 前后的值来决定是否需要上报 UI 提示。
public enum CapabilityValidator {
    public static func clamp(_ preset: CameraPreset, capability: DeviceCapability) -> CameraPreset {
        var clamped = preset
        if let iso = clamped.manual?.iso {
            clamped.manual?.iso = min(max(iso, capability.isoRange.lowerBound), capability.isoRange.upperBound)
        }
        if let bias = clamped.manual?.exposureBias {
            clamped.manual?.exposureBias = min(max(bias, capability.evRange.lowerBound), capability.evRange.upperBound)
        }
        if !capability.supportsRAW, clamped.captureFormat != .heif {
            clamped.captureFormat = .heif
        }
        return clamped
    }
}

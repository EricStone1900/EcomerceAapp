import CameraCore
import CameraPipeline

/// clamp 之后按 clamped 参数依次驱动手动控制、渲染链插件、分析链插件——三步各自独立失败不互相
/// 影响（手动控制的 apply 可能因为设备暂时不支持某个 control 而抛错，不应该连带阻止 processor/
/// analyzer 的注册）。ProcessedPreview 是走 .passthrough 还是 .processed，由 `processors.isEmpty`
/// 决定（Stage 2 已定义的规则），本类型不直接持有/切换 `PreviewMode`（那是 CameraUI 的类型，
/// `CameraFeature` 不应该反向依赖 UI 层）——调用方可以用 `resolvedProcessorCount > 0` 自己映射。
///
/// 显式声明 `Sendable`（见 `ThermalPolicyUseCase` 顶部注释，同样的理由：Swift 对 public 类型的
/// 隐式 Sendable 推导不保证跨模块可靠传播）。
public struct PresetUseCase: Sendable {

    private let cameraSource: any CameraSourceProtocol
    private let pipeline: PipelineController
    private let registry: PluginRegistry

    public init(cameraSource: any CameraSourceProtocol, pipeline: PipelineController, registry: PluginRegistry) {
        self.cameraSource = cameraSource
        self.pipeline = pipeline
        self.registry = registry
    }

    /// 返回 clamp 后实际生效的 Preset（跟传入的 preset 不相等时，调用方应该向用户提示"部分参数
    /// 已按当前镜头能力自动调整"）+ 实际解析出来的 processor 数量（用来决定预览模式）。
    @discardableResult
    public func apply(_ preset: CameraPreset, capability: DeviceCapability) async -> (clamped: CameraPreset, processorCount: Int) {
        let clamped = CapabilityValidator.clamp(preset, capability: capability)

        if let manual = clamped.manual {
            if let iso = manual.iso {
                try? await cameraSource.apply(.setISO(iso))
            }
            if let bias = manual.exposureBias {
                try? await cameraSource.apply(.setExposureBias(bias))
            }
        }

        let processors = registry.resolveProcessors(clamped.processorIDs)
        let analyzers = registry.resolveAnalyzers(clamped.analyzerIDs)
        await pipeline.setProcessors(processors)
        await pipeline.setAnalyzers(analyzers)

        return (clamped, processors.count)
    }
}

import CameraPipeline

/// App 组合根往这里注册所有 `FrameProcessor` / `FrameAnalyzer` 实现，`PresetUseCase` 按 ID 解析。
/// 新增能力 = 新类型 + `registry.register` 一行，这个类型本身不需要因为新插件而改动——是"L1/L2/L4
/// 零改动扩展新插件"这条验收标准落地的地方：`CameraFeature` 在编译期完全不知道
/// `CameraVision`/`CameraML`/`CameraFilters` 里任何具体类型的存在，只认它们共同实现的
/// `FrameProcessor`/`FrameAnalyzer` 协议。
///
/// `@unchecked Sendable` 建立在"注册只发生在 App 组合根启动阶段一次性完成，之后只读"这个使用
/// 约定上（不是真正线程安全的并发字典）——如果以后需要支持运行时热插拔插件，这里要么换成
/// actor，要么加锁。
public final class PluginRegistry: @unchecked Sendable {
    private var processors: [String: any FrameProcessor] = [:]
    private var analyzers: [String: any FrameAnalyzer] = [:]

    public init() {}

    public func register(_ processor: any FrameProcessor, id: PluginID) {
        processors[id.rawValue] = processor
    }

    public func register(_ analyzer: any FrameAnalyzer, id: PluginID) {
        analyzers[id.rawValue] = analyzer
    }

    public func resolveProcessors(_ ids: [String]) -> [any FrameProcessor] {
        ids.compactMap { processors[$0] }
    }

    public func resolveAnalyzers(_ ids: [String]) -> [any FrameAnalyzer] {
        ids.compactMap { analyzers[$0] }
    }
}

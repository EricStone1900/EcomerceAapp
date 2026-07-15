/// 分析类：异步、可丢帧，产出元数据而非修改帧。preferredFPS 由各插件独立声明采样率。
public protocol FrameAnalyzer: Sendable {
    var id: PluginID { get }
    var preferredFPS: Int { get }
    func analyze(_ frame: Frame) async -> [Annotation]
}

import Foundation

/// 页面生命周期追踪 UseCase 协议。
/// 接收页面标识符 + 停留时长，发送埋点事件到 Analytics 模块。
public protocol TrackPageLifecycleUseCaseProtocol {

    /// 记录页面停留事件。
    /// - Parameters:
    ///   - pageIdentifier: 页面唯一标识符
    ///   - duration: 页面停留时长（秒）
    ///   - extraParameters: 附加参数字典（可选）
    func start(pageIdentifier: String, duration: TimeInterval, extraParameters: [String: Any]?)
}

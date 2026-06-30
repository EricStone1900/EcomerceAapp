import Foundation

/// 所有可触发的原生动作，随项目扩展持续添加枚举 case。
public enum NativeBridgeAction {
    // 导航
    case pushRoute(route: String, params: [String: Any])
    case presentSheet(route: String, params: [String: Any])
    case dismiss

    // 系统能力
    case openCamera
    case requestLocation
    case shareContent(String)

    // 通用
    case callFunction(name: String, params: [String: Any])
    case showAlert(title: String, message: String)
    case none
}

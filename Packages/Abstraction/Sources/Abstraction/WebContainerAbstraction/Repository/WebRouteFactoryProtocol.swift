import UIKit

/// WebContainer 路由工厂协议。
/// App 层（Composition Root）实现此协议，将路由名 + 参数解析为具体的 UIViewController。
/// 实现此解耦后，WebContainerFeature 无需反向依赖任何业务 Feature 包。
public protocol WebRouteFactoryProtocol {
    /// 根据路由名和参数生成目标 ViewController
    /// - Parameters:
    ///   - route: 路由标识，如 "productDetail"、"webTestNativeScreen"
    ///   - params: 动态参数字典，如 ["productId": "42"]
    /// - Returns: 目标 ViewController，如果无法解析则返回 nil
    func makeViewController(route: String, params: [String: Any]) -> UIViewController?
}

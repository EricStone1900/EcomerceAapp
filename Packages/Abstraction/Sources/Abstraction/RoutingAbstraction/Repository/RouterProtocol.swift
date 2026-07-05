import Foundation

/// 导航路由协议。
/// App 层（Composition Root）实现此协议，负责全局导航调度。
///
/// 职责：
/// - 维护导航栈（UINavigationController 栈）
/// - 路由到 ViewController 的转换调度
/// - 返回上一页
///
/// 使用方式（App 层典型代码）：
/// ```swift
/// let router: RouterProtocol = AppRouter(navigationController: nav)
/// router.navigate(to: ProductDetailRoute(productId: "42"), configuration: .default)
/// ```
public protocol RouterProtocol {

    /// 导航到指定路由。
    /// - Parameters:
    ///   - route: 目标路由值
    ///   - configuration: 导航配置，所有属性传 nil 表示走系统默认行为
    func navigate(to route: AppRoute, configuration: RouteConfiguration)

    /// 返回上一页。
    /// - Parameter animated: 是否带动画
    func goBack(animated: Bool)
}

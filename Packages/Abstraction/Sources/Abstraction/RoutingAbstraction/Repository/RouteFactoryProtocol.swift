import UIKit

/// 路由工厂协议。
/// 各业务模块在 App 层（Composition Root）实现此协议，
/// 将抽象路由值解析为具体的 UIViewController 实例。
///
/// - `canHandle(_:)`：判断当前工厂是否能够处理指定路由
/// - `makeViewController(for:)`：根据路由创建对应的 ViewController
///
/// 使用方式（App 层典型代码）：
/// ```swift
/// final class ProductRouteFactory: RouteFactoryProtocol {
///     func canHandle(_ route: AppRoute) -> Bool { route is ProductRoute }
///     func makeViewController(for route: AppRoute) -> UIViewController? {
///         guard let route = route as? ProductRoute else { return nil }
///         return ProductDetailViewController(productId: route.productId)
///     }
/// }
/// ```
public protocol RouteFactoryProtocol {

    /// 判断当前工厂是否能处理该路由。
    /// - Parameter route: 目标路由
    /// - Returns: 是否能处理
    func canHandle(_ route: AppRoute) -> Bool

    /// 根据路由生成目标 ViewController。
    /// - Parameter route: 目标路由
    /// - Returns: 目标 ViewController；无法解析时返回 nil
    func makeViewController(for route: AppRoute) -> UIViewController?
}

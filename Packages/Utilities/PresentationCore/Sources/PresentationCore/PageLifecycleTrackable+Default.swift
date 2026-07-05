import Foundation

import RoutingAbstraction

/// PageLifecycleTrackable 默认实现扩展。
///
/// 业务页面若仅需提供页面标识符（无需额外参数），
/// 只需实现 `analyticsPageIdentifier` 属性，
/// `analyticsExtraParameters` 默认返回 nil。
///
/// 使用示例：
/// ```swift
/// final class ProductDetailViewController: UIViewController, PageLifecycleTrackable {
///     let analyticsPageIdentifier: String = "product_detail"
///     // analyticsExtraParameters 默认返回 nil，无需实现
/// }
/// ```
extension PageLifecycleTrackable {

    public var analyticsExtraParameters: [String: Any]? { nil }
}

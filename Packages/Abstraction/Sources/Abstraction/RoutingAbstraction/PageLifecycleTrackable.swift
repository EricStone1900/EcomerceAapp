import Foundation

/// 页面生命周期可追踪协议。
/// 遵循此协议的页面可向 Analytics 模块提供自定义埋点信息。
///
/// 此协议为阶段 4（页面停留埋点 UseCase 与基类方案）预留，
/// 使得 Analytics 模块无需感知具体业务页面类型。
///
/// 使用方式：
/// ```swift
/// final class ProductDetailViewController: UIViewController, PageLifecycleTrackable {
///     let analyticsPageIdentifier: String = "product_detail"
///     var analyticsExtraParameters: [String: Any]? {
///         ["product_id": productId]
///     }
/// }
/// ```
public protocol PageLifecycleTrackable: AnyObject {

    /// 页面唯一标识符，用于 Analytics 埋点事件名称。
    /// 推荐格式：`"模块名_页面名"`（如 `"product_detail"`、`"cart_list"`）
    var analyticsPageIdentifier: String { get }

    /// 附加埋点参数字典。
    /// 值为 nil 时表示当前页面无额外参数需要上报。
    var analyticsExtraParameters: [String: Any]? { get }
}

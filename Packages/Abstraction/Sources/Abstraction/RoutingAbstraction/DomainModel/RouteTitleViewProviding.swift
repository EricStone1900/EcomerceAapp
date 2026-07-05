import UIKit

/// 自定义导航栏标题视图提供协议。
/// 当标准文本/富文本无法满足 UI 需求时，
/// 通过实现此协议提供完全自定义的 UIView 作为导航栏 titleView。
///
/// 使用场景：
/// - 品牌 Logo 作为标题
/// - 图文混合标题
/// - 可交互的自定义标题区域（如分段控件）
/// - 加载动画指示器
public protocol RouteTitleViewProviding: AnyObject {

    /// 创建并返回自定义标题视图。
    /// - Returns: 将设置为导航栏 titleView 的 UIView
    func makeTitleView() -> UIView
}

import Foundation

/// 导航栏标题配置。
/// 控制页面标题的显示方式：纯文本、富文本或自定义视图。
public enum RouteTitleConfiguration {

    /// 纯文本标题。
    /// - Parameter text: 标题字符串
    case text(String)

    /// 富文本标题。
    /// - Parameter attributedText: 富文本属性字符串
    case attributedText(NSAttributedString)

    /// 自定义标题视图。
    /// - Parameter customTitleView: 遵循 RouteTitleViewProviding 协议的视图提供者
    case customTitleView(RouteTitleViewProviding)
}

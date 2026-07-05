import UIKit

/// 返回按钮配置。
/// 控制导航栏返回按钮的显示行为和样式。
public enum RouteBackButtonConfiguration {

    /// 使用系统默认返回按钮（系统自动管理标题和手势）
    case systemDefault

    /// 隐藏返回按钮（适用于全屏模态或引导流程）
    case hidden

    /// 自定义返回按钮
    /// - Parameters:
    ///   - title: 自定义按钮标题；传 nil 则不显示标题
    ///   - image: 自定义按钮图标；传 nil 则不显示图标
    case custom(title: String?, image: UIImage?)
}

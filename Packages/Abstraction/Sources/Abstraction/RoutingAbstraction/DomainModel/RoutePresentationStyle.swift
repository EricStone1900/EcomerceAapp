import Foundation

/// 页面展示样式。
/// 决定跳转时目标页面的呈现方式：推入导航栈或模态展示。
public enum RoutePresentationStyle {

    /// 推入当前导航栈（对应 UINavigationController.pushViewController）
    case push

    /// 模态展示，可指定模态样式（对应 present(_:animated:completion:)）
    case present(modal: RouteModalStyle)
}

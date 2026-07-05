#if canImport(UIKit)
import UIKit
#endif

/// 转场动画配置。
/// 控制页面切换时的动画效果。
public enum RouteTransition {

    /// 使用系统默认转场（导航栈默认滑动，模态默认垂直弹出）
    case systemDefault

    /// 使用预置系统转场动画
    case system(RouteSystemTransition)

    /// 使用自定义动画提供者
    case custom(RouteAnimatorProviding)
}

/// 预置系统转场动画类型。
/// 映射 iOS UIKit 提供的标准转场动画效果。
public enum RouteSystemTransition {

    /// 淡入淡出
    case fade

    /// 从左侧滑入
    case slideLeft

    /// 从右侧滑入
    case slideRight

    /// 从上方滑入
    case slideUp

    /// 从下方滑入
    case slideDown

    /// 水平翻转
    case flipHorizontal

    /// 交叉溶解
    case crossDissolve
}

/// 自定义转场动画提供协议。
/// 外部需实现 UIViewControllerAnimatedTransitioning 协议的全部方法，
/// 用于提供完全自定义的页面切换动画。
///
/// 使用场景：
/// - 需要特殊动画效果的营销落地页
/// - 品牌定制化过渡动画
/// - 双向交互式转场
#if canImport(UIKit)
public protocol RouteAnimatorProviding: UIViewControllerAnimatedTransitioning {
}
#else
public protocol RouteAnimatorProviding {
}
#endif

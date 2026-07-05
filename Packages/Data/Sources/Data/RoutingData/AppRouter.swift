import Foundation

import RoutingAbstraction

#if canImport(UIKit)
import UIKit

// MARK: - UIKit 实现（iOS 环境）

/// 应用级导航路由器。
///
/// 实现 RouterProtocol，负责：
/// - 将 AppRoute 解析为 UIViewController 并执行 push/present
/// - 支持和应用动画转场（系统内置 + 自定义）
/// - 维护导航元数据栈，使 goBack 能智能选择 pop 或 dismiss
/// - 应用 RouteBackButtonConfiguration
///
/// 对 UINavigationController / UITabBarController 使用弱引用，避免循环引用。
public final class AppRouter: RouterProtocol {

    private weak var navigationController: UINavigationController?

    private weak var tabBarController: UITabBarController?

    private let factoryRegistry: RouteFactoryRegistry

    /// 导航元数据栈。每次 navigate 记录一条，goBack 时 pop。
    private var navigationMetadata: [NavigationType] = []

    /// 当前活跃的转场协调器（用于自定义动画时防止提前释放）
    private var activeTransitionCoordinator: TransitioningCoordinator?

    private enum NavigationType {

        case push

        case present
    }

    public init(
        navigationController: UINavigationController?,
        tabBarController: UITabBarController?,
        factoryRegistry: RouteFactoryRegistry
    ) {

        self.navigationController = navigationController
        self.tabBarController = tabBarController
        self.factoryRegistry = factoryRegistry
    }

    // MARK: - RouterProtocol

    public func navigate(to route: AppRoute, configuration: RouteConfiguration) {

        guard let viewController = factoryRegistry.viewController(for: route) else { return }

        applyBarVisibilityIfNeeded(configuration.barVisibility)
        applyTitleIfNeeded(configuration.titleConfiguration, to: viewController)

        let style = configuration.presentationStyle ?? .push

        switch style {
        case .push:
            applyPushTransitionIfNeeded(configuration.transition)
            navigationController?.pushViewController(viewController, animated: isDefaultAnimation(configuration.transition))
            navigationMetadata.append(.push)

        case .present(let modalStyle):
            viewController.modalPresentationStyle = modalStyle.toUIModalPresentationStyle()
            applyPresentTransitionIfNeeded(configuration.transition, to: viewController)
            let presenting = navigationController ?? topmostViewController()
            presenting.present(viewController, animated: true)
            navigationMetadata.append(.present)
        }

        applyBackButtonConfiguration(configuration.backButton, to: viewController)
        activeTransitionCoordinator = nil
    }

    public func goBack(animated: Bool) {

        guard let lastType = navigationMetadata.popLast() else {

            // 元数据栈为空时退化为 pop（兼容未记录的场景）
            navigationController?.popViewController(animated: animated)
            return
        }

        switch lastType {
        case .push:
            navigationController?.popViewController(animated: animated)

        case .present:
            navigationController?.dismiss(animated: animated)
        }
    }

    // MARK: - Transition Helpers

    /// systemDefault 或 nil = 用系统默认动画（animated: true）
    private func isDefaultAnimation(_ transition: RouteTransition?) -> Bool {

        transition == nil || {
            if case .systemDefault = transition! { return true }
            return false
        }()
    }

    /// 为 push 场景应用动画配置。
    private func applyPushTransitionIfNeeded(_ transition: RouteTransition?) {

        guard let transition, let nav = navigationController else { return }

        switch transition {
        case .systemDefault:
            break

        case .system(let systemTransition):
            let anim = CATransition()
            anim.duration = 0.35
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            anim.type = systemTransition.catTransitionType
            anim.subtype = systemTransition.catTransitionSubtype
            nav.view.layer.add(anim, forKey: kCATransition)

        case .custom:
            let coordinator = TransitioningCoordinator(transition: transition)
            activeTransitionCoordinator = coordinator
            nav.delegate = coordinator
        }
    }

    /// 为 present 场景应用动画配置。
    private func applyPresentTransitionIfNeeded(_ transition: RouteTransition?, to viewController: UIViewController) {

        guard let transition else { return }

        switch transition {
        case .systemDefault:
            break

        case .system(let systemTransition):
            viewController.modalTransitionStyle = systemTransition.modalTransitionStyle

        case .custom:
            let coordinator = TransitioningCoordinator(transition: transition)
            activeTransitionCoordinator = coordinator
            viewController.transitioningDelegate = coordinator
        }
    }

    // MARK: - Private Helpers

    private func applyBarVisibilityIfNeeded(_ config: RouteBarVisibilityConfiguration?) {

        guard let config = config else { return }
        let animated = config.animated ?? true
        if let hidesNavBar = config.hidesNavigationBar {
            navigationController?.setNavigationBarHidden(hidesNavBar, animated: animated)
        }
    }

    private func applyTitleIfNeeded(_ config: RouteTitleConfiguration?, to viewController: UIViewController) {

        guard let config = config else { return }

        switch config {
        case .text(let text):
            viewController.title = text

        case .attributedText(let attributedText):
            viewController.title = attributedText.string

        case .customTitleView:
            break
        }
    }

    private func applyBackButtonConfiguration(_ config: RouteBackButtonConfiguration?, to viewController: UIViewController) {

        guard let config = config else { return }

        switch config {
        case .systemDefault:
            viewController.navigationItem.hidesBackButton = false

        case .hidden:
            viewController.navigationItem.hidesBackButton = true

        case .custom(let title, _):
            viewController.navigationItem.hidesBackButton = false
            if let title {
                let backItem = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
                viewController.navigationItem.backBarButtonItem = backItem
            }
        }
    }

    /// 获取当前最顶层的 ViewController，用于无导航栈时的降级展示。
    private func topmostViewController() -> UIViewController {

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {

            var top = rootVC
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }

        return UIViewController()
    }
}

// MARK: - RouteModalStyle → UIModalPresentationStyle

private extension RouteModalStyle {

    func toUIModalPresentationStyle() -> UIModalPresentationStyle {

        switch self {
        case .fullScreen:  return .fullScreen
        case .pageSheet:   return .pageSheet
        case .formSheet:   return .formSheet
        case .automatic:   return .automatic
        }
    }
}

// MARK: - RouteSystemTransition → CATransition

private extension RouteSystemTransition {

    var catTransitionType: CATransitionType {

        switch self {
        case .fade:           return .fade
        case .slideLeft,
             .slideRight:     return .push
        case .slideUp,
             .slideDown:      return .moveIn
        case .flipHorizontal: return .reveal
        case .crossDissolve:  return .fade
        }
    }

    var catTransitionSubtype: CATransitionSubtype? {

        switch self {
        case .fade:           return nil
        case .slideLeft:      return .fromRight
        case .slideRight:     return .fromLeft
        case .slideUp:        return .fromTop
        case .slideDown:      return .fromBottom
        case .flipHorizontal: return nil
        case .crossDissolve:  return nil
        }
    }
}

// MARK: - RouteSystemTransition → UIModalTransitionStyle

private extension RouteSystemTransition {

    var modalTransitionStyle: UIModalTransitionStyle {

        switch self {
        case .fade:           return .crossDissolve
        case .slideLeft,
             .slideRight,
             .slideUp,
             .slideDown:      return .coverVertical
        case .flipHorizontal: return .flipHorizontal
        case .crossDissolve:  return .crossDissolve
        }
    }
}

// MARK: - 自定义动画示例：FadeScaleAnimator

/// 缩放淡入淡出动画示例。
/// 作为自定义动画的参考实现，展示如何遵循 RouteAnimatorProviding 协议。
///
/// 使用方式：
/// ```swift
/// var config = RouteConfiguration()
/// let animator = FadeScaleAnimator()
/// config.transition = .custom(animator)
/// router.navigate(to: route, configuration: config)
/// ```
public final class FadeScaleAnimator: NSObject, RouteAnimatorProviding {

    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.4
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {

        guard let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        let container = transitionContext.containerView
        container.addSubview(toView)

        toView.alpha = 0.0
        toView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)

        let duration = transitionDuration(using: transitionContext)

        UIView.animate(withDuration: duration) {
            toView.alpha = 1.0
            toView.transform = .identity
        } completion: { finished in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

#else

// MARK: - 空实现（macOS/Linux 编译环境）

/// 空路由器，用于非 iOS 环境编译。
public final class AppRouter: RouterProtocol {

    private let factoryRegistry: RouteFactoryRegistry

    public init(
        navigationController: Any? = nil,
        tabBarController: Any? = nil,
        factoryRegistry: RouteFactoryRegistry
    ) {

        self.factoryRegistry = factoryRegistry
    }

    public func navigate(to route: AppRoute, configuration: RouteConfiguration) {

        // 非 iOS 环境为空操作
    }

    public func goBack(animated: Bool) {

        // 非 iOS 环境为空操作
    }
}

#endif

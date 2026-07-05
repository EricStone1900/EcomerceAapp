import Foundation

import RoutingAbstraction

#if canImport(UIKit)
import UIKit

// MARK: - UIKit 实现（iOS 环境）

/// 转场协调器，负责桥接自定义 RouteAnimatorProviding 与 UIKit 转场代理系统。
///
/// 职责：
/// - push/pop 场景：作为 UINavigationControllerDelegate，返回 RouteAnimatorProviding 转场对象
/// - present/dismiss 场景：作为 UIViewControllerTransitioningDelegate，返回 RouteAnimatorProviding 转场对象
///
/// 使用方式：
/// AppRouter 在遇到 `.custom(RouteAnimatorProviding)` 时创建此协调器，
/// 设为当前跳转的 delegate，跳转完成后由 AppRouter 负责清理引用。
internal final class TransitioningCoordinator: NSObject {

    private let transition: RouteTransition

    init(transition: RouteTransition) {
        self.transition = transition
    }
}

// MARK: - UINavigationControllerDelegate

extension TransitioningCoordinator: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {

        guard case .custom(let animator) = transition else { return nil }
        return animator
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension TransitioningCoordinator: UIViewControllerTransitioningDelegate {

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {

        guard case .custom(let animator) = transition else { return nil }
        return animator
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {

        guard case .custom(let animator) = transition else { return nil }
        return animator
    }
}

#endif

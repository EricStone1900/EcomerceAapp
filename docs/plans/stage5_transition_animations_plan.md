# Stage 5: 过渡动画 —— 系统默认 + 自定义

## Context

阶段 1 的 `RouteConfiguration` 已包含 `transition` 属性（类型 `RouteTransition?`），但阶段 3 的 `AppRouter` 从未读取它——所有跳转均使用 UIKit 默认动画。本阶段让 `configuration.transition` 真正生效。

## 设计概要

两条动画路径：

**路径 A — 系统内置动画**（最可靠，最小侵入）：
- Push 场景：`CATransition` 作用在 `navigationController.view.layer` 上，然后执行 `pushViewController(animated: false)`
- Present 场景：设置 `viewController.modalTransitionStyle`，然后执行 `present(animated: true)`

**路径 B — 自定义动画**（通过 `RouteAnimatorProviding`）：
- `TransitioningCoordinator` 实现 `UINavigationControllerDelegate` 和 `UIViewControllerTransitioningDelegate`
- 将 `RouteAnimatorProviding` 直接作为 `UIViewControllerAnimatedTransitioning` 返回给 UIKit

## 修改文件（3 个）

### 1. `Sources/Data/RoutingData/AppRouter.swift`

修改 `navigate(to:configuration:)` 方法，按以下顺序读取并应用 `configuration.transition`：

```
1. 从 factoryRegistry 获取 ViewController
2. 应用 barVisibility / titleConfiguration
3. 读取 configuration.transition
4. push 分支:
   - .systemDefault → 不处理，用系统默认动画
   - .system(RouteSystemTransition) → 创建 CATransition 加到 nav 层
   - .custom(RouteAnimatorProviding) → 创建 TransitioningCoordinator 设为 nav.delegate
5. present 分支:
   - .systemDefault → 不处理，用系统默认动画
   - .system(RouteSystemTransition) → 设置 viewController.modalTransitionStyle
   - .custom(RouteAnimatorProviding) → 创建 TransitioningCoordinator 设为 vc.transitioningDelegate
6. 执行 push / present
7. 应用 backButton 配置
```

### 2. `Sources/Data/RoutingData/TransitioningCoordinator.swift`（新增）

```swift
#if canImport(UIKit)
import UIKit
import RoutingAbstraction

/// 转场协调器，负责桥接自定义 RouteAnimatorProviding 与 UIKit 转场代理系统。
///
/// 职责：
/// - push/pop 场景：作为 UINavigationControllerDelegate
/// - present/dismiss 场景：作为 UIViewControllerTransitioningDelegate
/// - 将 RouteAnimatorProviding 作为 UIViewControllerAnimatedTransitioning 返回给 UIKit
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
```

### 3. `Sources/Abstraction/RoutingAbstraction/Compatibility.swift`

补充 macOS 编译所需的 delegate 协议桩：

```swift
#if !canImport(UIKit)

public protocol UIViewControllerAnimatedTransitioning {}
open class UIViewController {}
open class UIView {}

// 为 Stage 5 TransitioningCoordinator 提供的协议桩
public protocol UINavigationControllerDelegate {}
public protocol UIViewControllerTransitioningDelegate {}

#endif
```

## AppRouter.swift 关键修改点

### `navigate()` 方法修改后结构：

```swift
public func navigate(to route: AppRoute, configuration: RouteConfiguration) {
    guard let viewController = factoryRegistry.viewController(for: route) else { return }

    applyBarVisibilityIfNeeded(configuration.barVisibility)
    applyTitleIfNeeded(configuration.titleConfiguration, to: viewController)

    let style = configuration.presentationStyle ?? .push

    switch style {
    case .push:
        if let transition = configuration.transition {
            applyPushTransition(transition)
        }
        navigationController?.pushViewController(viewController, animated: transitionConfig == nil)
        navigationMetadata.append(.push)

    case .present(let modalStyle):
        viewController.modalPresentationStyle = modalStyle.toUIModalPresentationStyle()
        if let transition = configuration.transition {
            applyPresentTransition(transition, to: viewController)
        }
        ...
    }
    applyBackButtonConfiguration(configuration.backButton, to: viewController)
}
```

### 新增私有方法：

```swift
private func applyPushTransition(_ transition: RouteTransition) {
    guard let nav = navigationController else { return }
    switch transition {
    case .systemDefault:
        break
    case .system(let systemTransition):
        applyCATransition(systemTransition, to: nav)
    case .custom(let animator):
        let coordinator = TransitioningCoordinator(transition: transition)
        activeAnimator = animator  // keep reference
        nav.delegate = coordinator
    }
}

private func applyCATransition(_ system: RouteSystemTransition, to nav: UINavigationController) {
    let anim = CATransition()
    anim.duration = 0.35
    anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    (anim.type, anim.subtype) = system.catTransitionParams
    nav.view.layer.add(anim, forKey: kCATransition)
}
```

### RouteSystemTransition → CATransition 映射：

```swift
private extension RouteSystemTransition {
    var catTransitionParams: (CATransitionType, CATransitionSubtype?) {
        switch self {
        case .fade:            return (.fade, nil)
        case .slideLeft:       return (.push, .fromRight)
        case .slideRight:      return (.push, .fromLeft)
        case .slideUp:         return (.moveIn, .fromTop)
        case .slideDown:       return (.moveIn, .fromBottom)
        case .flipHorizontal:  return (.reveal, nil)
        case .crossDissolve:   return (.fade, nil)
        }
    }
}
```

### RouteSystemTransition → UIModalTransitionStyle 映射：

```swift
private extension RouteSystemTransition {
    var modalTransitionStyle: UIModalTransitionStyle {
        switch self {
        case .fade:            return .crossDissolve
        case .slideLeft:       return .coverVertical
        case .slideRight:      return .coverVertical
        case .slideUp:         return .coverVertical
        case .slideDown:       return .coverVertical
        case .flipHorizontal:  return .flipHorizontal
        case .crossDissolve:   return .crossDissolve
        }
    }
}
```

## 示例自定义动画（参考）

提供 FadeScaleAnimator 示例作为自定义动画的参考实现：

```swift
/// 缩放淡入淡出动画示例。
/// 作为 RouteAnimatorProviding 的参考实现，后续业务方可参考此模式接入自定义动画。
public final class FadeScaleAnimator: RouteAnimatorProviding {
    
    private let isPresenting: Bool

    public init(isPresenting: Bool) {
        self.isPresenting = isPresenting
    }

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

        let duration = transitionDuration(using: transitionContext)
        let startScale: CGFloat = isPresenting ? 0.6 : 1.0
        let endScale: CGFloat = isPresenting ? 1.0 : 0.6

        toView.transform = CGAffineTransform(scaleX: startScale, y: startScale)
        toView.alpha = isPresenting ? 0.0 : 1.0

        UIView.animate(withDuration: duration) {
            toView.transform = CGAffineTransform(scaleX: endScale, y: endScale)
            toView.alpha = isPresenting ? 1.0 : 0.0
        } completion: { finished in
            toView.transform = .identity
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
```

此示例放在何处？由于 `RouteAnimatorProviding` 定义在 `RoutingAbstraction`（纯协议层），示例实现应放在 `RoutingData` 包中，作为参考。

## 执行顺序

1. `Compatibility.swift` — 补充 delegate 协议桩
2. `TransitioningCoordinator.swift` — 新增协调器
3. `AppRouter.swift` — 修改 navigate 读取 transition
4. 验证：`cd Packages/Data && swift build`

## 验收清单

- [ ] 不设 transition（nil / .systemDefault）时行为与之前完全一致
- [ ] `RouteTransition.system(.fade)` push 页面产生淡入效果
- [ ] `RouteTransition.system(.slideLeft)` push 页面产生从右推入效果
- [ ] `RouteTransition.system(.flipHorizontal)` present 页面产生水平翻转效果
- [ ] `RouteTransition.system(.crossDissolve)` present 页面产生交叉溶解效果
- [ ] `RouteTransition.custom(FadeScaleAnimator)` push 页面产生缩放淡入效果
- [ ] `cd Packages/Data && swift build` 编译通过

# Stage 6: 导航栏 / TabBar 显示隐藏

## Context

`RouteBarVisibilityConfiguration` 已在阶段 1 定义，但 `AppRouter` 只实现了 `hidesNavigationBar`，完全忽略了 `hidesTabBar`。本阶段让所有可见性配置完整生效，且保证与页面跳转动画同步、无跳变。

## 修改文件

仅修改 **`Packages/Data/Sources/Data/RoutingData/AppRouter.swift`**，改动集中在 3 处：

### 1. `navigate()` 方法 — 新增防抖保护 + 传参给 applyBarVisibilityIfNeeded

```swift
public func navigate(to route: AppRoute, configuration: RouteConfiguration) {
    // 防抖：导航动画进行中时忽略新请求，避免栏状态错乱
    guard !isTransitioning else { return }

    guard let viewController = factoryRegistry.viewController(for: route) else { return }

    let style = configuration.presentationStyle ?? .push
    applyBarVisibilityIfNeeded(configuration.barVisibility, for: viewController, isPush: style.isPush)
    applyTitleIfNeeded(configuration.titleConfiguration, to: viewController)

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
```

### 2. 新增 `isTransitioning` 计算属性

```swift
/// 导航控制器当前是否正在执行转场动画。
/// 用于防止连续快速触发跳转时出现栏状态错乱、黑屏或卡死。
private var isTransitioning: Bool {
    navigationController?.transitionCoordinator != nil
}
```

### 3. 重写 `applyBarVisibilityIfNeeded()`

```swift
/// 应用导航栏与 TabBar 可见性配置。
/// - Parameter viewController: 目标页面（用于设置 hidesBottomBarWhenPushed）
/// - Parameter isPush: 当前是否为 push 跳转（tabBar 隐藏仅对 push 有效）
private func applyBarVisibilityIfNeeded(
    _ config: RouteBarVisibilityConfiguration?,
    for viewController: UIViewController,
    isPush: Bool
) {
    guard let config = config else { return }
    let animated = config.animated ?? true

    // 导航栏隐藏/显示
    if let hidesNavBar = config.hidesNavigationBar {
        navigationController?.setNavigationBarHidden(hidesNavBar, animated: animated)
    }

    // TabBar 隐藏/显示（仅 push 场景有效）
    if let hidesTabBar = config.hidesTabBar, isPush {
        // hidesBottomBarWhenPushed 在 push 之前设置，
        // UIKit 自动将 tabBar 的隐藏/显示与 push/pop 动画同步。
        viewController.hidesBottomBarWhenPushed = hidesTabBar
    }
}
```

### 补充：`RoutePresentationStyle` 扩展

```swift
private extension RoutePresentationStyle {
    var isPush: Bool {
        if case .push = self { return true }
        return false
    }
}
```

## 设计说明

### TabBar 隐藏
选择 `hidesBottomBarWhenPushed` 而非 `tabBar.isHidden`：
- UIKit 原生支持，自动与 push/pop 动画同步
- push 时 tabBar 随页面从右滑出，pop 时从左滑回，无需手动管理 transitionCoordinator
- pop 返回后 tabBar 自动恢复显示

### 防抖保护
- `transitionCoordinator` 在 push/pop 调用后立即变为非 nil，直到动画完成
- 动画进行中的新跳转被忽略，避免栏状态错乱

## 执行顺序

1. `AppRouter.swift` — 修改 3 处（`navigate()` + `isTransitioning` + `applyBarVisibilityIfNeeded`）
2. 验证：`cd Packages/Data && swift build`

## 验收清单

- [ ] `isTransitioning` 防止连续快速触发跳转
- [ ] `hidesNavigationBar = true` 时 push，导航栏与页面动画同步消失
- [ ] pop 返回时导航栏与页面动画同步恢复
- [ ] `hidesTabBar = true` 时 push，tabBar 随页面滑出
- [ ] pop 返回时 tabBar 自动恢复显示
- [ ] `cd Packages/Data && swift build` 编译通过

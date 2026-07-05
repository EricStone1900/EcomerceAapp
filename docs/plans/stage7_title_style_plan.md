# Stage 7: 导航栏标题样式可配置

## Context

`RouteTitleConfiguration` 已在阶段 1 定义（`.text` / `.attributedText` / `.customTitleView`），但 `AppRouter` 的 `applyTitleIfNeeded()` 仅设置了 `viewController.title`，忽略了 `attributedText` 的样式属性，`customTitleView` 也是空操作。本阶段让标题样式完整生效。

## 实现方案

利用 iOS 13+ 的 **per-page `UINavigationBarAppearance`**（通过 `viewController.navigationItem.standardAppearance` 设置），每个 ViewController 可自定义自己的标题样式而不影响其他页面。UIKit 在 pop 时自动恢复上一页的外观，无需手动管理。

## 修改文件（仅 1 个）

### `Packages/Data/Sources/Data/RoutingData/AppRouter.swift`

重写 `applyTitleIfNeeded()` 方法，完整支持 3 种配置：

```swift
private func applyTitleIfNeeded(_ config: RouteTitleConfiguration?, to viewController: UIViewController) {
    guard let config = config else { return }

    switch config {
    case .text(let text):
        viewController.title = text

    case .attributedText(let attributedText):
        viewController.title = attributedText.string
        applyAttributedTitleStyle(attributedText, to: viewController)

    case .customTitleView(let provider):
        viewController.navigationItem.titleView = provider.makeTitleView()
    }
}
```

新增 `applyAttributedTitleStyle()` 私有方法：

```swift
/// 创建 per-page UINavigationBarAppearance，应用富文本标题样式。
/// - 从 NSAttributedString 中提取 font / foregroundColor / alignment 等属性
/// - 设置到 viewController.navigationItem.standardAppearance / scrollEdgeAppearance
/// - 不影响 BaseNavigationController 设置的全局默认样式
private func applyAttributedTitleStyle(_ attributedText: NSAttributedString, to viewController: UIViewController) {
    let range = NSRange(location: 0, length: attributedText.length)
    let attributes = attributedText.attributes(at: 0, effectiveRange: nil)

    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.titleTextAttributes = attributes
    appearance.largeTitleTextAttributes = attributes

    viewController.navigationItem.standardAppearance = appearance
    viewController.navigationItem.scrollEdgeAppearance = appearance
    viewController.navigationItem.compactAppearance = appearance
}
```

## 设计说明

### Per-page appearance 如何工作
- `UIViewController.navigationItem.standardAppearance`（iOS 13+）允许每个 VC 独立设置导航栏外观
- 设置为 nil 时使用 `UINavigationBar` 的全局 appearance（即 BaseNavigationController 设置的）
- pop 返回时 UIKit 自动恢复上一页的 appearance，无样式污染

### 三种配置的处理

| 配置 | viewController.title | navigationItem 外观 | titleView |
|------|---------------------|-------------------|-----------|
| `.text(String)` | ✅ 设置 | 不变（使用全局默认） | 不变 |
| `.attributedText(NSAttributedString)` | ✅ 设置 | ✅ per-page appearance（字体/颜色/对齐） | 不变 |
| `.customTitleView(RouteTitleViewProviding)` | 不变 | 不变 | ✅ provider.makeTitleView() |

## 执行顺序

1. `AppRouter.swift` — 重写 `applyTitleIfNeeded` + 新增 `applyAttributedTitleStyle`
2. 验证：`cd Packages/Data && swift build`

## 验收清单

- [ ] `.text("标题")` 按系统默认样式显示
- [ ] `.attributedText(NSAttributedString)` 应用字体/颜色属性
- [ ] `.customTitleView(provider)` 正确设置 navigationItem.titleView
- [ ] pop 返回后上一页导航栏样式未被污染（per-page appearance 机制）
- [ ] 未配置 titleConfiguration 的页面使用 BaseNavigationController 全局默认样式
- [ ] `cd Packages/Data && swift build` 编译通过

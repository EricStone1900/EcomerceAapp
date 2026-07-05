# Stage 9 — 手动验收清单

> UIKit 强依赖项的验证方法，不对其编写自动化测试。

---

## 1. AppRouter push/present 导航

| 验收项 | 步骤 | 预期结果 |
|--------|------|----------|
| Push 基本导航 | 调用 `router.navigate(to: route, configuration: .default)` 且 `presentationStyle = push` | 页面推入导航栈，工具栏显示后退按钮 |
| Present 模态展示 | 调用 `router.navigate()` 且 `presentationStyle = .present(modal: .pageSheet)` | 模态弹起，遮罩层半透明，关闭手势有效 |
| Present fullScreen | `presentationStyle = .present(modal: .fullScreen)` | 全屏模态展示，无遮罩 |
| Rapid-tap 防抖 | 快速多次调用 `navigate(to:)` | 仅第一次有效，后续被 `isTransitioning` 阻止 |

## 2. goBack 元数据栈

| 验收项 | 步骤 | 预期结果 |
|--------|------|----------|
| Push 后 goBack | Push 后调用 `router.goBack(animated:)` | pop 回上一页 |
| Present 后 goBack | Present 后调用 `router.goBack(animated:)` | dismiss 模态页 |
| 空栈退化 | 导航栈只有一页时 goBack | 退化为 `popViewController`（系统默认行为） |

## 3. 转场动画

| 验收项 | 步骤 | 预期结果 |
|--------|------|----------|
| 系统默认动画 | `transition = .systemDefault` | UIKit 默认 push/present 动画 |
| 系统预置 SlideLeft | `transition = .system(.slideLeft)` | push 时页面从左侧滑入 |
| 系统预置 Fade | `transition = .system(.crossDissolve)` | 页面交叉淡入淡出 |
| 自定义动画器 | `transition = .custom(animator)`，提供 `RouteAnimatorProviding` 实例 | 动画器回调被 UIKit 调用 |

## 4. 返回按钮配置

| 验收项 | 步骤 | 预期结果 |
|--------|------|----------|
| 隐藏返回按钮 | `backButton = .hidden` | 目标页无返回按钮 |
| 自定义返回按钮 | `backButton = .custom(title: "返回", image: nil)` | 返回按钮显示"返回"文字 |
| 系统默认 | `backButton = .systemDefault` | 显示正常返回按钮（箭头 + 上一页标题） |

## 5. 导航栏/TabBar 可见性

| 验收项 | 步骤 | 预期结果 |
|--------|------|----------|
| 隐藏导航栏 | `barVisibility.hidesNavigationBar = true` | push 后导航栏隐藏，pop 时恢复 |
| 隐藏 TabBar | `barVisibility.hidesTabBar = true` | push 后 TabBar 隐藏（`hidesBottomBarWhenPushed`），pop 恢复 |
| 非动画 | `barVisibility.animated = false` | 无动画切换可见性 |

## 6. 标题配置

| 验收项 | 步骤 | 预期结果 |
|--------|------|----------|
| 纯文本标题 | `titleConfiguration = .text("我的页面")` | 导航栏显示"我的页面" |
| 富文本标题 | `titleConfiguration = .attributedText(...)` | 使用自定义属性字符串渲染标题 |
| 自定义 titleView | `titleConfiguration = .customTitleView(provider)` | 导航栏替换为自定义 UIView |
| 页面间切换恢复 | 页面 A 设置自定义标题 → push 页面 B 设置不同标题 → pop 返回 A | A 的标题恢复正确（`UINavigationBarAppearance` 机制） |

## 7. BaseHostingController 页面停留埋点

| 验收项 | 步骤 | 预期结果 |
|--------|------|----------|
| 自动埋点触发 | 进入页面 → 等待数秒 → 返回前页 | `TrackPageLifecycleUseCaseProtocol.start()` 被调用 |
| 页面标识符正确 | 实现 `PageLifecycleTrackable` 的页面 | 埋点使用 `analyticsPageIdentifier` 值 |
| 兜底标识符 | 未实现 `PageLifecycleTrackable` 且未调用 `setPageIdentifier()` | 使用 `"unknown_page"` |
| 持续时间为 0 | 快速进入后退回 | `duration` 趋近于 0（不会崩溃） |

## 8. BaseNavigationController 统一外观

| 验收项 | 步骤 | 预期结果 |
|--------|------|----------|
| 标题字体 | 任意路由页面 | 17pt semibold（标准模式下） |
| 大标题字体 | 设置 `prefersLargeTitles = true` | 34pt bold |
| 返回按钮图标 | 任意页面 | 使用 `chevron.left` SF Symbol，tint 为 systemBlue |
| 子类自定义 | 继承 `BaseNavigationController` 并重写 `configureAppearance()` | 统一外观被覆盖为新样式 |

---

## 验收状态

- AppRouter push/present: □ 通过 □ 失败
- AppRouter goBack 元数据栈: □ 通过 □ 失败
- 转场动画（系统/自定义）: □ 通过 □ 失败
- 返回按钮配置: □ 通过 □ 失败
- 导航栏/TabBar 可见性: □ 通过 □ 失败
- 标题配置: □ 通过 □ 失败
- BaseHostingController 埋点: □ 通过 □ 失败
- BaseNavigationController 外观: □ 通过 □ 失败

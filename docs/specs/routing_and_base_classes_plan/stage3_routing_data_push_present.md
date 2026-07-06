# 阶段 3：搭建 RoutingData —— push / present + 智能返回按钮

> 前置依赖：阶段 1（RoutingAbstraction）、阶段 2（RoutingDomain）已完成
> 说明：本文档为实施计划，不含具体代码实现

---

## 项目整体架构解析

项目采用 **Clean Architecture + SPM 模块化**，核心原则是严格的依赖倒置：外层依赖内层协议，内层永远不知道外层的存在。

```
Presentation/Features  →  Domain  →  Abstraction  ←  Data
        │                                           ↑
        │                    ┌──────────────────────┘
        └──── Utilities ─────┘
```

| 层 | 职责 | 依赖规则 |
|---|---|---|
| **Abstraction** | 纯协议层 | 仅 Swinject/RxSwift；UIKit 不算"项目依赖" |
| **Domain** | UseCase 业务编排 | 仅依赖 Abstraction 协议 |
| **Data** | Repository/Service 具体实现，真正调用系统 API | 依赖 Abstraction 协议 |
| **Presentation** | SwiftUI Feature 包 | 依赖 Domain 协议、Abstraction、Utilities |
| **Utilities** | 横切工具 | 可依赖 Abstraction 协议 |
| **App 层** | 组合根 | 唯一允许"知道所有 Feature"的层 |

**关键先例**：\`NativeBridgeRouter.dispatch(action:)\` 已经在用 \`UINavigationController\` 做 push/present 调度，本阶段的 \`AppRouter\` 是对这套能力的正式化、通用化封装。DI 用 \`DIContainer.shared\`（Swinject）。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API（\`-environment dev\`），无需后端即可跑通全流程
- 单测：\`cd Packages/XxxDomain && swift test\`


---

## 上文衔接

阶段 1 完成了路由相关的全部协议与配置模型；阶段 2 完成了 `NavigateUseCase`（跳转编排）与 `TrackPageLifecycleUseCase`（埋点），均已有单测覆盖，且都不依赖 UIKit 具体实现。

## 本阶段目标

实现最基础、最核心的路由跳转能力：push / present + 返回按钮的智能来源判断。本阶段暂不涉及自定义动画、栏隐藏、标题样式（后续阶段实现），先把地基打稳。

## 需要实现的内容

新建 `RoutingData` 包，依赖 `RoutingAbstraction`：

- `RouteFactoryRegistry`：持有多个 `RouteFactoryProtocol` 实例的容器，跳转时遍历 `canHandle` 找到匹配的工厂产出 `UIViewController`
- `AppRouter`：实现 `RouterProtocol`
  - 持有根导航容器（`UINavigationController`/`UITabBarController`）的弱引用，避免循环引用
  - 实现 `navigate(to:configuration:)` 的 push 分支（`pushViewController`）与 present 分支（`present`，先支持系统默认的 `.fullScreen`/`.pageSheet` 等）
  - 实现跳转元数据记录：每次跳转时记录"本次是 push 还是 present"到一个轻量的导航元数据栈里，供返回按钮判断使用
  - 实现 `RouteBackButtonConfiguration` 的应用：显示/隐藏返回按钮；自定义按钮点击后，根据元数据自动调用 `popViewController` 或 `dismiss`，业务方不需要关心具体调用哪个
- `DI/RoutingDataAssembly.swift`：注册 `AppRouter`、`RouteFactoryRegistry`

## 联调建议

用工程里现有的两个页面做实际验证，比如让 `ProductListView` 跳转到 `BasketView` 分别走一次 push 和一次 present，观察返回按钮行为是否正确。

## 验收清单

- [ ] 能从任意一个已有页面，通过新路由跳转到另一个已有页面
- [ ] push 进去的页面点击返回按钮后正确执行 `popViewController`
- [ ] present 进去的页面点击返回按钮后正确执行 `dismiss`
- [ ] 返回按钮可以配置为完全隐藏
- [ ] `AppRouter` 对根导航容器使用弱引用，跳转后无内存泄漏（用 Xcode Memory Graph 检查）

## 下一阶段预告

阶段 4 将搭建 `PresentationCore`，实现 `BaseHostingController`/`BaseNavigationController` 两个基类，落地"统一导航栏 UI"与"页面停留时长自动埋点"这两个横切能力，业务方无需逐页实现。

# 阶段 1：搭建 RoutingAbstraction（协议与配置模型）

> 本阶段可独立执行，无需依赖后续阶段代码
> 说明：本文档为实施计划，不含具体代码实现

---

## 项目整体架构解析

项目采用 **Clean Architecture + SPM 模块化**，核心原则是严格的依赖倒置：外层依赖内层协议，内层永远不知道外层的存在，也不知道具体实现。

```
Presentation/Features  →  Domain  →  Abstraction  ←  Data
        │                                           ↑
        │                    ┌──────────────────────┘
        └──── Utilities ─────┘
```

| 层 | 职责 | 依赖规则 |
|---|---|---|
| **Abstraction** | 纯协议层，零业务实现，是全项目唯一的公共契约 | 仅 Swinject/RxSwift；UIKit 等系统框架不算"项目依赖" |
| **Domain** | UseCase 业务编排 | 仅依赖 Abstraction 协议 + RxSwift |
| **Data** | Repository/Service 具体实现 | 依赖 Abstraction 协议 + Networking |
| **Presentation** | SwiftUI Feature 包 | 依赖 Domain 协议、Abstraction、Utilities |
| **Utilities** | 网络、埋点等横切工具，被所有 Feature 共用 | 可依赖 Abstraction 协议 |
| **App 层** | 组合根，DI 装配、聚合各 Feature | 唯一允许"知道所有 Feature"的层 |

**关键先例**：WebContainer 模块的 `WebRouteFactoryProtocol` 定义在 Abstraction，具体解析推迟到 App 层的 `AppWebRouteFactory.swift`；`NativeBridgeRouter` 已用 `UINavigationController` 承载 `UIHostingController` 做导航调度；DI 用 `DIContainer.shared`（Swinject），运行时通过 `resolve()` 解析。

## 如何使用现有工程

- `xed .` 打开工程，DEBUG 默认走 Mock API（`-environment dev`），无需后端即可跑通全流程
- 切换生产环境：Scheme 加 launch argument `-environment prd`
- 新增业务模块标准套路：Abstraction 定协议 → Domain 写 UseCase → Data 写 Repository/Service → Presentation 写 View/ViewModel → 各层 DI 注册
- 单测：`cd Packages/XxxDomain && swift test`


---

## 本阶段目标

新建 `RoutingAbstraction` SPM 包，作为全局路由功能唯一的公共契约层。只定义协议/枚举/结构体，不写任何实现逻辑，为后续所有阶段打地基。

## 需要实现的内容

- `AppRoute`：路由标记协议，各业务 Feature 的具体路由值需遵循它
- `RouteFactoryProtocol`：`canHandle(_ route: AppRoute) -> Bool`、`makeViewController(for route: AppRoute) -> UIViewController?`
- `RouterProtocol`：`navigate(to route: AppRoute, configuration: RouteConfiguration)`、`goBack(animated: Bool)`
- `RoutePresentationStyle`：`.push` / `.present(modal: RouteModalStyle)`
- `RouteModalStyle`：对应系统 `.fullScreen`、`.pageSheet`、`.formSheet` 等
- `RouteTransition`：`.systemDefault` / `.system(内置几种)` / `.custom(RouteAnimatorProviding)`
- `RouteAnimatorProviding`：外部自定义动画需实现的协议（对应 `UIViewControllerAnimatedTransitioning`）
- `RouteBackButtonConfiguration`：`.hidden` / `.systemDefault` / `.custom(title/icon)`
- `RouteBarVisibilityConfiguration`：`hidesNavigationBar`、`hidesTabBar`、`animated`
- `RouteTitleConfiguration`：标题文本/字体/颜色/对齐，或自定义 titleView 占位协议
- `RouteConfiguration`：聚合以上所有配置项，作为 `navigate(to:configuration:)` 的入参，需提供"全部走系统默认"的便捷构造方式
- `PageLifecycleTrackable`：可选协议，`analyticsPageIdentifier: String`、`analyticsExtraParameters: [String: Any]?`，供页面自定义埋点信息（为阶段 4 的基类方案预留）

## 依赖要求

仅依赖 Swinject（后续 DI 注册用）与 UIKit（系统框架）。不依赖项目内任何其他包。

## 验收清单

- [ ] 包可独立编译通过，无任何实现逻辑，只有协议/类型声明
- [ ] 未引入除 Swinject/UIKit 外的任何依赖
- [ ] `RouteConfiguration` 提供合理的默认值/便捷构造方式
- [ ] 所有类型命名清晰，注释说明每个协议的职责边界

## 下一阶段预告

阶段 2 将基于本阶段的协议，实现 Domain 层的 `NavigateUseCase` 跳转编排逻辑，以及扩展 Analytics 模块的页面停留埋点 UseCase。

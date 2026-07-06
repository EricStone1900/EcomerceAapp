# 阶段 4：搭建 PresentationCore —— BaseHostingController / BaseNavigationController

> 前置依赖：阶段 1-3（RoutingAbstraction、RoutingDomain、RoutingData）已完成
> 说明：本文档为实施计划，不含具体代码实现

---

## 项目整体架构解析

项目采用 **Clean Architecture + SPM 模块化**，核心原则是严格的依赖倒置。

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
| **Data** | Repository/Service 具体实现 | 依赖 Abstraction 协议 |
| **Presentation** | SwiftUI Feature 包 | 依赖 Domain 协议、Abstraction、Utilities |
| **Utilities** | 横切工具，被所有 Feature 共用（如 Analytics、RxSwift↔Combine 桥接） | 可依赖 Abstraction 协议 |
| **App 层** | 组合根 | 唯一允许"知道所有 Feature"的层 |

**设计思路**：页面停留时长埋点、统一导航栏 UI 属于横切关注点，如果让每个 Feature 各写一遍会导致代码重复、容易漏埋、口径不统一。工程是 UIKit \`UINavigationController\` 承载 \`UIHostingController\` 的混合导航结构，用 UIKit 基类拦截 \`viewWillAppear\`/\`viewWillDisappear\` 生命周期是最不会漏埋点的方式，比 SwiftUI 的 \`.onAppear\`/\`.onDisappear\` 在 push/present 场景下更可靠。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程


---

## 上文衔接

阶段 3 已完成核心跳转能力（push/present + 智能返回按钮），并用现有页面联调验证通过。本阶段开始落地"统一导航栏 UI"与"页面停留时长自动埋点"这两个横切能力。

## 本阶段目标

新建 `PresentationCore`（Utilities 层）包，提供两个基类，让所有通过路由框架创建的页面自动获得统一 UI 与自动埋点能力，业务方不需要逐页手动实现。

## 需要实现的内容

新建 `PresentationCore` 包，依赖 `RoutingAbstraction`（配置模型）、`AnalyticsAbstraction`（埋点 UseCase 协议）、Swinject：

- `BaseHostingController`：`UIHostingController` 的子类
  - 在 `viewWillAppear` 记录进入时间戳
  - 在 `viewWillDisappear` 计算停留时长，调用 `TrackPageLifecycleUseCaseProtocol`（通过 DI 解析）发送埋点，业务方无感知
  - 应用 `RouteBackButtonConfiguration`：设置/隐藏返回按钮
  - 应用 `RouteTitleConfiguration`：标题文本样式或自定义 titleView
- `BaseNavigationController`：`UINavigationController` 的子类
  - 统一设置导航栏默认外观（字体、颜色、分割线、返回箭头图标等设计规范）—— 这是"统一 Navi UI"的具体实现位置
  - 作为 `AppRouter` 实际操作的根容器
- `PageLifecycleTrackable` 的协议扩展默认实现：未主动实现该协议的页面，用路由标识符兜底埋点，保证不会漏埋
- `DI/PresentationCoreAssembly.swift`：注册基类运行时所需的依赖解析方式

## 需要改造的内容

- 回到阶段 3 的 `AppRouter`：让它创建/操作的页面统一改为使用 `BaseHostingController`，根容器改为 `BaseNavigationController`

## 验收清单

- [ ] 任选一个已迁移到新路由的页面，进入停留 N 秒后返回，验证埋点事件的时长数值大致准确
- [ ] 完全没有实现 `PageLifecycleTrackable` 的页面，也能拿到默认埋点标识符，不会崩溃或漏埋
- [ ] 统一导航栏外观（字体/颜色/返回箭头）在多个页面间表现一致
- [ ] 修改一次 `BaseNavigationController` 里的样式设置，多个页面同步生效，无需逐个修改

## 下一阶段预告

阶段 5 将实现过渡动画：系统默认动画分支，以及可插拔的自定义动画注入能力。

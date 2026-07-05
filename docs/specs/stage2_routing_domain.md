# 阶段 2：搭建 RoutingDomain + 埋点 UseCase 扩展

> 前置依赖：阶段 1（RoutingAbstraction）已完成
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
| **Abstraction** | 纯协议层，零业务实现 | 仅 Swinject/RxSwift；UIKit 不算"项目依赖" |
| **Domain** | UseCase 业务编排 | 仅依赖 Abstraction 协议 + RxSwift |
| **Data** | Repository/Service 具体实现 | 依赖 Abstraction 协议 + Networking |
| **Presentation** | SwiftUI Feature 包 | 依赖 Domain 协议、Abstraction、Utilities |
| **Utilities** | 网络、埋点等横切工具 | 可依赖 Abstraction 协议 |
| **App 层** | 组合根 | 唯一允许"知道所有 Feature"的层 |

**关键先例**：\`AnalyticsWrapper\`（Utilities 层）已有"发送事件到 \`POST /analytics/event\`"的能力，\`AnalyticsDomain\` 已有 \`SendProductDetailAnalyticsDataUseCase\` 作为埋点 UseCase 的先例，本阶段新增的埋点 UseCase 直接复用这套基础设施。DI 用 \`DIContainer.shared\`（Swinject），运行时通过 \`resolve()\` 解析。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API（\`-environment dev\`），无需后端即可跑通全流程
- 新增业务模块标准套路：Abstraction 定协议 → Domain 写 UseCase → Data 写实现 → Presentation 写 View/ViewModel → 各层 DI 注册
- 单测：\`cd Packages/XxxDomain && swift test\`


---

## 上文衔接

阶段 1 已完成 `RoutingAbstraction`，包含路由/跳转/动画/返回按钮/栏可见性/标题/埋点相关的全部协议与配置模型，均为纯声明无实现。

## 本阶段目标

实现路由跳转的业务编排逻辑，以及页面停留时长埋点的 UseCase，均不涉及任何 UIKit 具体操作。

## 需要实现的内容

### 1. 新建 `RoutingDomain` 包

- 依赖 `RoutingAbstraction`
- `NavigateUseCase`：接收 `AppRoute` + `RouteConfiguration`，做前置校验（可预留"是否登录才能跳转"一类的校验钩子）后调用注入进来的 `RouterProtocol`
- `DI/RoutingDomainAssembly.swift`：注册 `NavigateUseCase`

### 2. 扩展已有的 Analytics 模块

- 在 `AnalyticsAbstraction` 中新增 `TrackPageLifecycleUseCaseProtocol`：接收页面标识符 + 停留时长（+ 可选额外参数）
- 在 `AnalyticsDomain` 中实现 `TrackPageLifecycleUseCase`，内部调用已有的 `AnalyticsWrapperProtocol` 发送事件，与现有 `SendProductDetailAnalyticsDataUseCase` 保持同样的调用范式
- 更新 `AnalyticsDomain` 的 DI 注册文件，加入新 UseCase 的注册

## 验收清单

- [ ] `NavigateUseCase` 只依赖 `RouterProtocol` 协议，不 import UIKit
- [ ] `NavigateUseCase` 有单测：mock `RouterProtocol`，验证 UseCase 正确转发跳转参数
- [ ] `TrackPageLifecycleUseCase` 有单测：给定页面标识符 + 时长，验证正确调用 `AnalyticsWrapperProtocol`
- [ ] 两个包（`RoutingDomain` 及更新后的 `AnalyticsDomain`）均可独立 `swift test` 通过

## 下一阶段预告

阶段 3 将实现 Data 层的 `AppRouter`，落地 push/present 的具体跳转能力，以及返回按钮的智能来源判断（push 场景 pop，present 场景 dismiss）。

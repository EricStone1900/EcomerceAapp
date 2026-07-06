# 阶段 8：接入现有 Feature，替换旧的跳转方式

> 前置依赖：阶段 1-7 已完成（路由功能 7 项需求全部实现完毕）
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

现有 Feature 包：\`LoginFeature\`、\`ProductsFeature\`、\`BasketFeature\`、\`WebContainerFeature\`。App 层的组合根（\`MyEcommerce/Routing/\`）是唯一允许"知道所有 Feature"的地方，本阶段的聚合注册工作在这里完成。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程
- 现有导航：\`LoginView → .fullScreenCover → TabView\`，Products/Basket/WebTest 三个 Tab，\`TabRouter\` 管理 Tab 状态


---

## 上文衔接

阶段 1-7 已经完成路由功能的全部能力建设：协议层、编排层、push/present、统一基类（埋点+导航栏 UI）、过渡动画、栏隐藏显示、标题样式。本阶段开始把这些能力接入到现有业务代码中。

## 本阶段目标

为现有四个 Feature 包补充路由定义，并在 App 层完成聚合注册，逐步替换掉旧的跳转方式，验证新旧过渡平滑。

## 需要实现的内容

### 1. 为每个 Feature 包补充路由定义

以 `ProductsFeature` 为例（`LoginFeature`/`BasketFeature`/`WebContainerFeature` 同理）：

- `Route/ProductRoute.swift`：定义该 Feature 暴露的路由值（如"商品详情"路由，携带商品 ID），遵循 `AppRoute`，如需自定义埋点标识符可同时遵循 `PageLifecycleTrackable`
- `Route/ProductRouteFactory.swift`：实现 `RouteFactoryProtocol`，用阶段 4 的 `BaseHostingController` 包装对应的 SwiftUI View
- 该 Feature 的 `DI/` 目录追加：把自己的 `RouteFactory` 注册进 `RouteFactoryRegistry`

### 2. App 层组合根

- 新建 `AppRouteFactoryRegistrar.swift`（`MyEcommerce/Routing/` 目录），仿照现有 `AppWebRouteFactory.swift` 的写法，在 App 启动时收集所有 Feature 的 `RouteFactory` 并注册进 `RouteFactoryRegistry`
- 在 `MyEcommerceApp.init()` 中追加 `RoutingAbstraction`/`RoutingDomain`/`RoutingData`/`PresentationCore` 的 DI 注册
- 创建根导航容器时使用阶段 4 的 `BaseNavigationController`，并绑定给 `AppRouter`

### 3. 评估旧跳转逻辑的替换

- 评估 `NativeBridgeRouter.dispatch(action:)` 内部的 push/present 调用是否直接替换为调用新的 `RouterProtocol`（替换后 WebContainer 的桥接命令处理逻辑可以变得更简洁，并天然获得动画/栏配置/埋点能力）

## 验收清单

- [ ] 商品列表 → 商品详情走新路由，且产出了对应的埋点数据
- [ ] WebContainer 的 `navigate` 类型桥接命令走新路由
- [ ] 全量跑通登录 → 商品列表 → 详情 → 加入购物车 → 购物车 → WebTest 主流程，无异常
- [ ] 新旧跳转方式共存期间（如果分批迁移），两者不互相干扰

## 下一阶段预告

阶段 9 是收尾阶段：补齐单元测试，更新项目文档（`docs/architecture.md`、`CLAUDE.md`），为后续新增可路由页面提供标准操作指引。

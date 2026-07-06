# 阶段 9：单元测试与文档收尾

> 前置依赖：阶段 1-8 已完成（路由功能全部实现并已接入现有业务）
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

工程已有 \`CLAUDE.md\`（AI 编码助手指令）与 \`docs/architecture.md\`（架构文档），本阶段的文档更新需保持与现有风格一致。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程
- 单测：\`cd Packages/XxxDomain && swift test\`，也可用 \`swift test --filter TestClassName/testMethodName\` 跑单个用例


---

## 上文衔接

阶段 8 完成后，路由功能的 7 项需求已经全部实现，并且已接入登录、商品、购物车、WebContainer 四个现有 Feature，主流程验证通过。本阶段是整个开发计划的收尾阶段。

## 本阶段目标

补齐自动化测试覆盖，更新项目文档，为后续团队成员或继续用 Claude Code 开发新页面提供清晰的操作指引。

## 需要实现的内容

### 1. 补齐单元测试

- `RoutingDomain` 的 `NavigateUseCase`：如阶段 2 尚未覆盖完整，本阶段补齐边界场景（如路由无法匹配到工厂时的处理）
- `TrackPageLifecycleUseCase`：补齐边界场景（如时长为 0、页面标识符为空等异常输入）
- `RoutingData`/`PresentationCore`：由于强依赖 UIKit，不追求视觉效果的自动化测试，采用"给定配置 → 断言调用了正确的 UIKit API"的有限单测思路（如断言 `setNavigationBarHidden` 被以正确参数调用）；复杂的动画/视觉效果以手动验收清单的方式留档，不强行自动化

### 2. 更新项目文档

- 更新 `docs/architecture.md`：补充路由模块（`RoutingAbstraction`/`RoutingDomain`/`RoutingData`/`PresentationCore`）的架构说明，保持与现有文档的风格、图示方式一致
- 更新 `CLAUDE.md`：补充"新增一个可路由页面"的标准操作步骤清单，例如：
  1. 在对应 Feature 包新建 `XxxRoute` 遵循 `AppRoute`
  2. 新建 `XxxRouteFactory` 遵循 `RouteFactoryProtocol`，用 `BaseHostingController` 包装 View
  3. 在该 Feature 的 DI 里注册到 `RouteFactoryRegistry`
  4. 如需自定义埋点标识符，额外遵循 `PageLifecycleTrackable`
  5. 调用方通过 `RouterProtocol.navigate(to:configuration:)` 发起跳转

## 验收清单

- [ ] `RoutingDomain`、`AnalyticsDomain` 新增 UseCase 的单测全部通过，覆盖正常场景与至少 1-2 个边界场景
- [ ] `RoutingData`/`PresentationCore` 有基础的 API 调用断言测试
- [ ] `docs/architecture.md` 已更新，风格与原文档一致
- [ ] `CLAUDE.md` 已更新"新增可路由页面"的标准步骤，团队新成员或新的 Claude Code 会话按此步骤即可独立完成新页面接入

## 收尾说明

至此，全局路由与通用 Navi/VC 基类方案（特性 1-7）全部开发完成并落地验证。后续如需扩展（比如深链接 Deep Link 支持、路由权限拦截等），可以在现有 `RoutingAbstraction`/`RoutingDomain` 的基础上平滑扩展，不需要改动已迁移页面的代码。

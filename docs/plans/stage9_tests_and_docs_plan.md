# Stage 9: 单元测试与文档收尾

## Context

前置依赖：阶段 1-8 已完成（路由功能全部实现并已接入现有业务）。

本阶段是整个路由系统开发计划的收尾阶段，补齐自动化测试覆盖并更新项目文档。

当前测试状态：

| 模块 | 现有测试 | 剩余空白 |
|------|----------|----------|
| RoutingDomain - NavigateUseCase | 3 个（正常转发/默认配置/自定义样式） | 缺少 goBack、多次调用 |
| AnalyticsDomain - TrackPageLifecycleUseCase | 3 个（正常/额外参数/空额外参数） | 缺少时长为0/负数、空标识符、多次调用 |
| RoutingData - RouteFactoryRegistry | 无测试目标 | 需要创建测试并启用 target |
| RoutingData - AppRouter | 无测试 | UIKit 强依赖，手动验收留档 |
| PresentationCore - BaseHostingController | 无测试 | UIKit 强依赖，手动验收留档 |

## 修改文件

### 1. `Packages/Domain/Tests/RoutingDomainTests/RoutingDomainTests.swift`
新增 2 个测试函数（Swift Testing 框架）：

- **`testNavigateUseCaseGoBack()`**: 验证 `goBack(animated:)` 传给 MockRouter，断言 `goBackCalled == true` 和 `goBackAnimated == true`
- **`testNavigateUseCaseMultipleNavigateCalls()`**: 验证多次 `execute` 调用，每次更新 MockRouter 记录的 `navigatedRoute` 和 `navigatedConfiguration`

### 2. `Packages/Domain/Tests/AnalyticsDomainTests/AnalyticsDomainTests.swift`
新增 4 个测试函数：

- **`testTrackPageLifecycleZeroDuration()`**: 调用 `start(pageIdentifier: "test", duration: 0)`，断言包含 `duration=0.0`
- **`testTrackPageLifecycleNegativeDuration()`**: 调用 `start(pageIdentifier: "test", duration: -1.0)`，断言不会崩溃
- **`testTrackPageLifecycleEmptyPageIdentifier()`**: 调用 `start(pageIdentifier: "", duration: 5.0)`，断言包含 `page=`
- **`testTrackPageLifecycleMultipleCalls()`**: 连续调用 3 次，断言 `trackedEvents.count == 3`

### 3. `Packages/Data/Package.swift`
启用 RoutingData 测试目标：将 `testsTargets` 中 `.RoutingData` 由 `return []` 改为 `return [.testTarget(framework: self, dependencies: testsDependencies)]`

`testsDependencies` 已定义 `[.internal(.RoutingData)]`，无需调整。

### 4. `Packages/Data/Tests/RoutingDataTests/RouteFactoryRegistryTests.swift`（新增）
创建测试文件，使用 Swift Testing 框架：

- **`testEmptyRegistryReturnsNil()`**: 无工厂时 `viewController(for:)` 返回 `nil`
- **`testRegisterAndRetrieve()`**: 注册工厂后，断言返回非 `nil` ViewController
- **`testMultipleFactoriesPriorityOrder()`**: 注册两个工厂，验证各自路由能找到对应工厂
- **`testNoMatchingFactoryReturnsNil()`**: 注册只处理 `RouteA` 的工厂，传 `RouteB`，返回 `nil`

### 5. `docs/architecture.md`
补充路由模块架构说明（保持原文档风格）：

- **Data 层**：新增 `RoutingData` 子模块（`RouteFactoryRegistry`、`AppRouter`、`TransitioningCoordinator`）
- **Utilities 层**：新增 `PresentationCore`（`BaseHostingController`、`BaseNavigationController`）
- **新增路由调用链**：`RouterProtocol → AppRouter → RouteFactoryRegistry → RouteFactoryProtocol → UIViewController`
- **更新包目录树**，增加 `RoutingAbstraction`、`RoutingDomain`、`RoutingData`、`PresentationCore`

### 6. `CLAUDE.md`
补充**"新增一个可路由页面"**标准操作步骤：

1. 在对应 Feature 包新建 `XxxRoute.swift`，定义枚举并遵循 `AppRoute`
2. 新建 `XxxRouteFactory.swift`，实现 `RouteFactoryProtocol`，用 `BaseHostingController` 包装 View
3. 在 `AppRouteFactoryRegistrar.swift` 中注册该工厂到 `RouteFactoryRegistry`
4. 如需自定义埋点标识符，让 View 遵循 `PageLifecycleTrackable`
5. 调用方通过 `RouterProtocol.navigate(to:configuration:)` 发起跳转

同时更新测试位置表，确认 `RoutingData` 测试存在状态。

### 7. `docs/plans/stage9_manual_verification_checklist.md`（新增）
手动验收清单，记录 UIKit 强依赖项的验收方法（不对其编写自动化测试）。

## 关键设计决策

1. **测试框架统一**：RoutingData 测试使用 Swift Testing 框架，与 Domain 测试一致。
2. **UIKit 不强制自动化**：AppRouter/PresentationCore 的 UIKit 交互通过手动验收清单留档。
3. **Package.swift 微调**：仅启用 RoutingData 测试 target，不新增外部依赖。

## 验证方式

```bash
# RoutingDomain 测试
cd Packages/Domain && swift test --filter RoutingDomainTests

# AnalyticsDomain 测试
cd Packages/Domain && swift test --filter AnalyticsDomainTests

# RoutingData 测试（新增）
cd Packages/Data && swift test --filter RoutingDataTests
```

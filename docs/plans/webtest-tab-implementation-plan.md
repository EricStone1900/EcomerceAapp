# WebTest Tab Implementation Plan

> Based on: `docs/specs/webtest-tab-plan.md`
> Goal: Implement the WebTest Tab feature including HTML test page, bridge infrastructure changes, tab integration, and DI wiring.

---

## Context

当前代码库已有完整的 WebContainer Feature 框架（`WebContainerView`、`WebContainerViewModel`、`NativeBridgeRouter`、`ProcessBridgeCommandUseCase` 等），但存在以下缺口：
- `NativeBridgeAction.pushRoute`/`presentSheet` **不支持参数传递**
- `NativeBridgeRouter` 使用闭包 `routeResolver`，**无法将 productId 等动态参数传给目标页面**
- `ProcessBridgeCommandUseCase` **没有参数合并逻辑**，规则匹配后直接返回 rule 的静态 nativeAction
- **没有本地测试 HTML 页面**来验证 Bridge 功能
- **没有 `WebTest` Tab** 入口
- **没有 App 层的路由组合根**（`WebRouteFactoryProtocol` 实现）

本计划分 5 个 Phase 依次实施，每个 Phase 可独立验证编译通过。

---

## Phase 1: Abstraction 层改造 (2 files)

### 1.1 修改 `NativeBridgeAction` → 支持 params

**文件**: `Packages/Abstraction/Sources/Abstraction/WebContainerAbstraction/DomainModel/NativeBridgeAction.swift`

将 `pushRoute(String)` 和 `presentSheet(String)` 改为带参数版本：

```swift
case pushRoute(route: String, params: [String: Any])
case presentSheet(route: String, params: [String: Any])
```

**影响**: 所有 `.pushRoute("xxx")` 和 `.presentSheet("xxx")` 调用点需要同步修改。

### 1.2 新建 `WebRouteFactoryProtocol`

**文件**: `Packages/Abstraction/Sources/Abstraction/WebContainerAbstraction/Repository/WebRouteFactoryProtocol.swift` (★ 新增)

```swift
import UIKit

public protocol WebRouteFactoryProtocol {
    func makeViewController(route: String, params: [String: Any]) -> UIViewController?
}
```

> 放在 Abstraction 层的 `Repository/` 目录下，与 `WebBridgeRuleRepositoryProtocol` 同级。

---

## Phase 2: 路由 & UseCase 改造 (2 files)

### 2.1 修改 `NativeBridgeRouter` → 依赖 `WebRouteFactoryProtocol`

**文件**: `Packages/Presentation/WebContainerFeature/Sources/WebContainerFeature/Bridge/NativeBridgeRouter.swift`

改动：
1. 构造函数参数：`routeResolver: @escaping (String) -> UIViewController?` → `routeFactory: WebRouteFactoryProtocol`
2. `dispatch(_:)` 中 `.pushRoute` 和 `.presentSheet` 的 case 改为调用 `routeFactory.makeViewController(route:params:)`
3. 除 `let route` 外同时提取 `let params` 传给新协议方法

### 2.2 修改 `ProcessBridgeCommandUseCase` → 增加参数合并逻辑

**文件**: `Packages/Domain/Sources/Domain/WebContainerDomain/ProcessBridgeCommandUseCase.swift`

在命中规则后，增加 `mergeParams` 步骤：将 `command.params`（来自 JS 的动态参数如 `productId`）合并进返回的 `NativeBridgeAction`：

```swift
private func mergeParams(rule: WebBridgeRule, command: WebBridgeCommand) -> NativeBridgeAction {
    switch rule.nativeAction {
    case .pushRoute(let route, _):
        return .pushRoute(route: route, params: command.params)
    case .presentSheet(let route, _):
        return .presentSheet(route: route, params: command.params)
    case .callFunction(let name, _):
        return .callFunction(name: name, params: command.params)
    default:
        return rule.nativeAction
    }
}
```

> 规则只负责"匹配"，参数永远来自运行时 `WebBridgeCommand`。

---

## Phase 3: App 层组合根 (2 files)

### 3.1 新建 `AppWebRouteFactory`

**文件**: `MyEcommerce/Routing/AppWebRouteFactory.swift` (★ 新增)

```swift
import UIKit
import Abstraction
import WebContainerFeature  // 用于 WebTestNativeProbeView

final class AppWebRouteFactory: WebRouteFactoryProtocol {
    func makeViewController(route: String, params: [String: Any]) -> UIViewController? {
        switch route {
        case "webTestNativeScreen":
            return UIHostingController(rootView: WebTestNativeProbeView())
        case "productDetail":
            // 未来可从 params 解析 productId 跳转真实商品页
            return nil
        default:
            return nil
        }
    }
}
```

> 注意：`WebTestNativeProbeView` 在 WebContainerFeature 包中，所以 App 层需依赖 `WebContainerFeature`。

### 3.2 更新 `MyEcommerceApp.swift` → DI 注册 + Tab 扩展

**文件**: `MyEcommerce/MyEcommerceApp.swift`

改动：
1. import 增加 `WebContainerFeature`（需要访问 `WebTestEntryView`）
2. DI 注册增加：
   - `WebRouteFactoryProtocol` → `AppWebRouteFactory`
   - `NativeBridgeRouter`（依赖 `WebRouteFactoryProtocol`）
   - `WebContainerViewModel`（依赖 `NativeBridgeRouter`）
3. `Screen` 枚举增加 `.webTest` case
4. `TabView` 增加第三个 Tab：`WebTestEntryView()`

> 需要确认 App Target 已依赖 `WebContainerFeature`，如果没有则需要修改 Xcode project。

---

## Phase 4: WebContainerFeature 资源 & Debug Views (5 files)

### 4.1 更新 `Package.swift` → 声明 resources

**文件**: `Packages/Presentation/WebContainerFeature/Package.swift`

在 `.target()` 调用中增加 `resources: [.copy("Resources")]` 参数。

### 4.2 新建 HTML 测试页面

**文件**: `Packages/Presentation/WebContainerFeature/Sources/WebContainerFeature/Resources/webtest.html` (★ 新增)

四个测试分组：
- **分组一**: 固定路由跳转（无参数）—「跳转原生测试页」「弹出 Sheet」「关闭当前页」
- **分组二**: 系统能力调用 —「打开相机」「分享文本」「弹出 Alert」
- **分组三**: 动态参数跳转商品详情页 — 输入框 +「跳转商品详情页」按钮
- **分组四**: 自定义函数调用 — JSON 输入框 +「调用自定义函数」按钮

页面底部：调用日志区，实时显示最近发送的消息。

JS Bridge 调用格式：
```javascript
window.webkit.messageHandlers.nativeBridge.postMessage({
    action: "navigate",
    target: "webTestNativeScreen",
    params: {}
});
```

### 4.3 新建 CSS 样式文件

**文件**: `Packages/Presentation/WebContainerFeature/Sources/WebContainerFeature/Resources/webtest-style.css` (★ 新增)

移动端优先样式，卡片式分组，按钮 44pt+，输入框视觉反馈。

### 4.4 新建 `WebTestEntryView`

**文件**: `Packages/Presentation/WebContainerFeature/Sources/WebContainerFeature/DebugEntry/WebTestEntryView.swift` (★ 新增)

```swift
public struct WebTestEntryView: View {
    public init() {}
    public var body: some View {
        // 从 DIContainer 解析 WebContainerViewModel
        // 在 onAppear 中加载本地 webtest.html
    }
}
```

### 4.5 新建 `WebTestNativeProbeView`

**文件**: `Packages/Presentation/WebContainerFeature/Sources/WebContainerFeature/DebugEntry/WebTestNativeProbeView.swift` (★ 新增)

简单探针页：显示「✅ 已从 WebTest 成功跳转」+ 时间戳。

---

## Phase 5: Bridge 规则更新 (1 file)

### 5.1 更新 `DIContainer+WebContainerData.swift`

**文件**: `Packages/Data/Sources/Data/WebContainerData/DI/DIContainer+WebContainerData.swift`

在 `initialRules` 数组中追加新规则：
- `navigate/webTestNativeScreen` → `.pushRoute(route: "webTestNativeScreen", params: [:])`
- `presentSheet/webTestNativeScreen` → `.presentSheet(route: "webTestNativeScreen", params: [:])`
- `shareContent` → `.shareContent("")` (params 在运行时被 command.params 覆盖)
- `showAlert` → `.showAlert(...)` (params 在运行时被 command.params 覆盖)

同时将现有 `pushRoute("productDetail")` 改为 `pushRoute(route: "productDetail", params: [:])`。

---

## 文件改动汇总

| # | 文件 | 操作 | Phase |
|---|------|------|-------|
| 1 | `NativeBridgeAction.swift` | ✎ 修改 | P1 |
| 2 | `WebRouteFactoryProtocol.swift` | ★ 新增 | P1 |
| 3 | `NativeBridgeRouter.swift` | ✎ 修改 | P2 |
| 4 | `ProcessBridgeCommandUseCase.swift` | ✎ 修改 | P2 |
| 5 | `AppWebRouteFactory.swift` | ★ 新增 | P3 |
| 6 | `MyEcommerceApp.swift` | ✎ 修改 | P3 |
| 7 | `WebContainerFeature/Package.swift` | ✎ 修改 | P4 |
| 8 | `webtest.html` | ★ 新增 | P4 |
| 9 | `webtest-style.css` | ★ 新增 | P4 |
| 10 | `WebTestEntryView.swift` | ★ 新增 | P4 |
| 11 | `WebTestNativeProbeView.swift` | ★ 新增 | P4 |
| 12 | `DIContainer+WebContainerData.swift` | ✎ 修改 | P5 |

**合计: 新增 6 文件, 修改 6 文件 = 12 文件**

---

## 验证清单

- [ ] Phase 1 编译通过（NativeBridgeAction 变更是 breaking change，需要同步更新调用点）
- [ ] Phase 2 编译通过（NativeBridgeRouter 和 ProcessBridgeCommandUseCase 改造完成）
- [ ] Phase 3 编译通过（App 层 DI 注册 + Tab 扩展）
- [ ] Phase 4 编译通过（资源 + Debug Views）
- [ ] Phase 5 编译通过（规则更新）
- [ ] 最终 Xcode 构建成功，无警告
- [ ] WebTest Tab 可正常显示，自动加载本地 webtest.html，CSS 正常渲染
- [ ] 点击「跳转原生测试页」→ push 到探针页，可正常返回
- [ ] 点击「弹出 Sheet」→ 以 Sheet 形式展示探针页，可 dismiss
- [ ] 输入任意 productId 点击「跳转商品详情页」→ 发送 bridge 消息，UseCase 接收并匹配规则
- [ ] 「打开相机」「分享文本」「弹出 Alert」按钮均触发对应系统行为
- [ ] 自定义函数调用分组可成功将任意 JSON params 送达 customFunctionHandlers

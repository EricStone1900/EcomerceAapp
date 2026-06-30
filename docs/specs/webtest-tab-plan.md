# WebTest Tab — 实现计划

> 在主 TabView 新增「WebTest」Tab，根页面加载本地测试 HTML，
> 验证 WebContainer Bridge 的导航能力（含带参数跳转商品详情页）
> 依赖：在 `webcont-feature-plan.md` 基础上扩展
> 计划版本：v1.0

---

## 0. 背景与目标

为验证 WebContainer Feature 是否正常工作，新增一个 **WebTest Tab**，根页面是一个本地 HTML 测试页，页面上提供多组输入框和按钮，覆盖以下场景：

1. 跳转到固定的原生测试界面（无参数）
2. 弹出 Sheet / 关闭 Sheet
3. 调用系统能力（相机 stub / 分享 / Alert）
4. **按用户输入的配置信息（如 productId）动态跳转商品详情页**（重点验证带参数的 Bridge 调用）

---

## 1. 需要先解决的架构缺口

在动手之前，先识别现有计划中两个需要补齐的点，否则带参数跳转商品详情页无法实现：

### 1.1 `NativeBridgeAction.pushRoute` 不支持参数

现有定义：

```swift
case pushRoute(String)   // 只有路由名，无法携带 productId
```

需要扩展为携带参数版本：

```swift
public enum NativeBridgeAction {
    case pushRoute(route: String, params: [String: Any])   // ✎ 修改
    case presentSheet(route: String, params: [String: Any]) // ✎ 修改
    case dismiss
    case openCamera
    case requestLocation
    case shareContent(String)
    case callFunction(name: String, params: [String: Any])
    case showAlert(title: String, message: String)
    case none
}
```

> 文件位置：`Abstraction/WebContainerAbstraction/DomainModel/NativeBridgeAction.swift`（已存在，本次为 ✎ 修改）

### 1.2 `NativeBridgeRouter` 的 `routeResolver` 不支持参数

现有签名 `(String) -> UIViewController?` 无法把 `productId` 传给 `ItemDetail` 页面，需要改为：

```swift
public typealias RouteFactory = (_ route: String, _ params: [String: Any]) -> UIViewController?
```

并新建一个 **RouteFactory 协议**放在 Abstraction 层，由 App 主入口（Composition Root）实现，因为只有 App 层能同时访问 `ProductsFeature`、`BasketFeature` 等所有 Presentation 包，避免 WebContainerFeature 反向依赖具体业务 Feature：

```swift
// Abstraction/WebContainerAbstraction/Repository/WebRouteFactoryProtocol.swift  ★ 新增
public protocol WebRouteFactoryProtocol {
    /// route: 如 "productDetail"；params: 如 ["productId": "42"]
    func makeViewController(route: String, params: [String: Any]) -> UIViewController?
}
```

`NativeBridgeRouter` 改为依赖该协议而非闭包：

```swift
public final class NativeBridgeRouter {
    private let routeFactory: WebRouteFactoryProtocol   // ✎ 替换原 routeResolver 闭包
    ...
    case .pushRoute(let route, let params):
        guard let vc = routeFactory.makeViewController(route: route, params: params) else { return }
        navigationController?.pushViewController(vc, animated: true)
}
```

### 1.3 在 App 层实现 `WebRouteFactoryProtocol`

**`MyEcommerce/Routing/AppWebRouteFactory.swift`** ★ 新增（App Target 内，非 Package）

```swift
import Abstraction
import ProductsFeature   // 已有 Feature 包，App 层可直接依赖

final class AppWebRouteFactory: WebRouteFactoryProtocol {
    func makeViewController(route: String, params: [String: Any]) -> UIViewController? {
        switch route {
        case "productDetail":
            guard let productId = params["productId"] as? String else { return nil }
            let vm = DIContainer.shared.resolve(ItemDetailViewModel.self, argument: productId)!
            return UIHostingController(rootView: ItemDetailView(viewModel: vm))

        case "webTestNativeScreen":
            return UIHostingController(rootView: WebTestNativeProbeView())

        default:
            return nil
        }
    }
}
```

> 这一步是关键解耦点：WebContainerFeature 完全不知道 `ProductsFeature` 的存在，路由表只存在于 App 组合根（Composition Root），符合 Clean Architecture 对 Feature 间解耦的要求。

---

## 2. Tab 结构改动

### 2.1 `TabRouter` 扩展

**文件**：现有 `TabRouter.swift`（具体路径视项目而定，通常在 `MyEcommerce/` 或某个 Navigation 工具包内）

```swift
enum AppTab: Hashable {
    case products
    case basket
    case webTest   // ★ 新增
}
```

### 2.2 主 TabView 改动

**文件**：现有承载 `TabView(Products / Basket)` 的 View（如 `MainTabView.swift`）

```swift
TabView(selection: $tabRouter.selectedTab) {
    ProductsView(...)
        .tabItem { Label("商品", systemImage: "bag") }
        .tag(AppTab.products)

    BasketView(...)
        .tabItem { Label("购物车", systemImage: "cart") }
        .tag(AppTab.basket)

    WebTestEntryView()                                    // ★ 新增
        .tabItem { Label("WebTest", systemImage: "globe") } // ★ 新增
        .tag(AppTab.webTest)                                // ★ 新增
}
```

### 2.3 `WebTestEntryView` — Tab 根页面

新建一个轻量包装 View，组装 `WebContainerView` 并预设加载本地测试 HTML，放在 **WebContainerFeature** 包内（属于该 Feature 的"自验证入口"，不需要单独建包）：

```
Packages/Presentation/WebContainerFeature/Sources/WebContainerFeature/
└── DebugEntry/
    └── WebTestEntryView.swift   ★ 新增
```

```swift
public struct WebTestEntryView: View {
    public init() {}

    public var body: some View {
        let viewModel = DIContainer.shared.resolve(WebContainerViewModel.self)!
        let handler = DIContainer.shared.resolve(WebScriptMessageHandler.self)!

        WebContainerView(viewModel: viewModel, messageHandler: handler)
            .onAppear {
                viewModel.loadWebContent(
                    .localFile(fileName: "webtest.html", bundle: .module)  // 见 §3.2
                )
            }
    }
}
```

---

## 3. 本地测试 HTML 资源

### 3.1 文件位置与资源声明

HTML 测试页属于 **WebContainerFeature** 包的资源，而非主 App Target 的 Assets（保持 Feature 自包含，便于未来复用/移除）：

```
Packages/Presentation/WebContainerFeature/
├── Package.swift                    ✎ 需声明 resources
└── Sources/WebContainerFeature/
    └── Resources/
        └── webtest.html             ★ 新增
        └── webtest-style.css        ★ 新增（同目录相对路径资源，验证本地资源加载能力）
```

**`Package.swift` 改动**：

```swift
.target(
    name: "WebContainerFeature",
    dependencies: [...],
    resources: [.copy("Resources")]   // ✎ 新增，使用 .copy 保留目录结构供相对路径引用
)
```

> 注意：SPM 资源默认放入 `Bundle.module`，因此 `LocalHTMLDataSource` 调用时需传入 `bundle: .module`，而非默认的 `.main`（§2.3 已体现）。需确认 §5（webcont-feature-plan.md）中 `LocalHTMLDataSource.resolve` 对自定义 bundle 的支持已经具备 —— 现有实现已接受 `bundle` 参数，无需改动。

### 3.2 HTML 页面内容规划（webtest.html）

页面分为四个测试分组，每组对应一类 Bridge 验证：

#### 分组一：固定路由跳转（无参数）

| 元素 | 行为 |
|---|---|
| 按钮「跳转原生测试页」 | 调用 `nativeBridge` 发送 `{action: "navigate", target: "webTestNativeScreen"}` |
| 按钮「弹出 Sheet」 | 发送 `{action: "presentSheet", target: "webTestNativeScreen"}` |
| 按钮「关闭当前页」 | 发送 `{action: "dismiss"}` |

#### 分组二：系统能力调用

| 元素 | 行为 |
|---|---|
| 按钮「打开相机」 | 发送 `{action: "openCamera"}` |
| 按钮「分享文本」 | 发送 `{action: "shareContent", params: {text: "来自WebTest的分享"}}` |
| 按钮「弹出 Alert」 | 发送 `{action: "showAlert", params: {title: "提示", message: "这是一条测试消息"}}` |

#### 分组三：动态参数跳转商品详情页（本计划核心验证点）

```
输入框 [productId]  默认占位符 "请输入商品ID，如 42"
按钮 [跳转商品详情页]
```

点击后读取输入框的值，组装并下发：

```javascript
function navigateToProductDetail() {
  const productId = document.getElementById('productIdInput').value.trim();
  if (!productId) {
    alert('请输入商品ID');
    return;
  }
  window.webkit.messageHandlers.nativeBridge.postMessage({
    action: "navigate",
    target: "productDetail",
    params: { productId: productId }
  });
}
```

对应原生侧：`ProcessBridgeCommandUseCase` 匹配 `action=navigate, target=productDetail` 规则 → `NativeBridgeAction.pushRoute(route: "productDetail", params: ["productId": productId])` → `NativeBridgeRouter` 调用 `AppWebRouteFactory.makeViewController` → 实例化真实的 `ItemDetailView`。

#### 分组四：自定义函数调用（验证 `.callFunction` 扩展点）

| 元素 | 行为 |
|---|---|
| 输入框 `functionParams`（JSON 格式，便于自由测试） | 例如 `{"key": "value"}` |
| 按钮「调用自定义函数」 | 发送 `{action: "callFunction", target: "logEvent", params: <输入的JSON>}` |

#### 页面底部：调用日志区

实时展示「最近一次发送的 Bridge 消息」和「原生侧返回的 ack」（见 §4.3），便于测试时直接在页面上确认收发是否成功，无需依赖 Xcode 控制台。

### 3.3 样式与布局要求

- 移动端优先，单列布局，按钮高度不小于 44pt 触控区域
- 分组用卡片样式区隔，标题标明验证目的（如"分组三：动态商品跳转"）
- 输入框失焦/按钮点击有明显视觉反馈，便于真机测试时确认点击生效

---

## 4. 新增/修改的 Bridge 规则

### 4.1 在 `WebContainerDataDI` 中追加规则注册

**文件**：`Data/WebContainerData/DI/WebContainerDataDI.swift`（✎ 修改，追加到现有 `initialRules` 数组）

```swift
WebBridgeRule(
    handlerName: "nativeBridge", action: "navigate", target: "webTestNativeScreen",
    nativeAction: .pushRoute(route: "webTestNativeScreen", params: [:]), priority: 10
),
WebBridgeRule(
    handlerName: "nativeBridge", action: "presentSheet", target: "webTestNativeScreen",
    nativeAction: .presentSheet(route: "webTestNativeScreen", params: [:]), priority: 10
),
WebBridgeRule(
    handlerName: "nativeBridge", action: "navigate", target: "productDetail",
    nativeAction: .pushRoute(route: "productDetail", params: [:]), priority: 10
    // 注意：params 在规则中为占位，实际 productId 来自 WebBridgeCommand.params，
    // 由 ProcessBridgeCommandUseCase 在匹配命中后用 command.params 覆盖 rule 中的占位 params
),
WebBridgeRule(
    handlerName: "nativeBridge", action: "shareContent", target: nil,
    nativeAction: .none, priority: 5   // 占位，实际 action 由 command.params 动态构造，见 §4.2
),
```

### 4.2 `ProcessBridgeCommandUseCase` 需要的逻辑补充

现有实现命中规则后直接返回 `rule.nativeAction`，但该 action 中的 `params` 是规则注册时的静态占位值，无法承载来自 JS 的动态输入（如 productId）。需要补充一步「参数合并」：命中规则后，将 `command.params` 合并进返回的 `NativeBridgeAction`（仅对 `.pushRoute` / `.presentSheet` / `.shareContent` / `.callFunction` 这类携带 params 的 case 生效）：

```swift
// ✎ ProcessBridgeCommandUseCase.execute 内，命中规则后增加一步
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

> 这一改动是本计划相对于上一份计划最重要的逻辑补充：**规则只负责"匹配"，不负责"携带最终参数"，参数永远来自运行时的 `WebBridgeCommand`**，保证同一条规则可以服务任意 productId，而不需要为每个商品 ID 注册一条规则。

### 4.3 调用日志回传（可选，便于测试页直接显示结果）

若需要让 HTML 页面上的"调用日志区"（§3.2 分组四下方）显示原生侧执行结果，需要在 `NativeBridgeRouter.dispatch` 执行完成后，通过 `WKWebView.evaluateJavaScript` 回传一个 ack：

```swift
// NativeBridgeRouter 新增一个可选回调，由 WebContainerViewModel 在初始化时注入
public var onActionDispatched: ((NativeBridgeAction, Bool) -> Void)?  // ★ 新增

// dispatch 每个 case 执行完成后调用：
onActionDispatched?(action, true)
```

`WKWebViewRepresentable.Coordinator` 监听该回调，调用：

```swift
webView.evaluateJavaScript("window.onNativeAck && window.onNativeAck(true)")
```

HTML 侧定义 `window.onNativeAck` 函数更新日志区文案。此部分为可选增强，不影响核心验证目标，可作为 P1 任务。

---

## 5. WebTest 专用原生测试页

为分组一、二提供一个简单的原生「探针页」，证明跳转/Sheet/Dismiss 链路确实生效，无需依赖真实业务页面：

**`Packages/Presentation/WebContainerFeature/Sources/WebContainerFeature/DebugEntry/WebTestNativeProbeView.swift`** ★ 新增

页面内容：仅展示一段文字「✅ 已从 WebTest 成功跳转」+ 当前时间戳（验证每次跳转都是新实例）+ 一个返回按钮。无业务逻辑，纯粹用于肉眼确认跳转链路畅通。

---

## 6. DI 注册顺序更新

**`MyEcommerce/MyEcommerceApp.swift`**（✎ 在已有基础上继续追加）

```swift
init() {
    // —— 现有注册（不变）——
    ProductDataDI.registerDependencies()
    ProductDomainDI.registerDependencies()
    BasketDataDI.registerDependencies()
    BasketDomainDI.registerDependencies()
    UserDataDI.registerDependencies()
    UserDomainDI.registerDependencies()
    AnalyticsDomainDI.registerDependencies()
    WebContainerDataDI.registerDependencies()
    WebContainerDomainDI.registerDependencies()

    // —— 新增：WebRouteFactory（必须在 WebContainerDomainDI 之后，
    //     因为 NativeBridgeRouter 在解析时依赖该协议实现）——
    DIContainer.shared.register(WebRouteFactoryProtocol.self) { _ in
        AppWebRouteFactory()
    }   // ★ 新增

    DIContainer.shared.register(NativeBridgeRouter.self) { resolver in
        NativeBridgeRouter(
            navigationController: AppNavigationContext.current,  // 现有导航上下文获取方式
            routeFactory: resolver.resolve(WebRouteFactoryProtocol.self)!
        )
    }   // ★ 新增（原计划中此注册被遗漏，本次补齐）
}
```

---

## 7. 文件改动汇总

| 文件 | 状态 | 说明 |
|---|---|---|
| `NativeBridgeAction.swift` | ✎ 修改 | `pushRoute`/`presentSheet` 增加 params |
| `WebRouteFactoryProtocol.swift` | ★ 新增 | Abstraction 层，解耦 WebContainer 与具体 Feature |
| `NativeBridgeRouter.swift` | ✎ 修改 | 依赖 `WebRouteFactoryProtocol` 替代闭包 |
| `AppWebRouteFactory.swift` | ★ 新增 | App Target 内，组合根路由实现 |
| `ProcessBridgeCommandUseCase.swift` | ✎ 修改 | 增加 params 合并逻辑 |
| `WebContainerDataDI.swift` | ✎ 修改 | 追加 4 条测试用 Bridge 规则 |
| `TabRouter`（现有文件） | ✎ 修改 | `AppTab` 增加 `.webTest` |
| `MainTabView`（现有文件） | ✎ 修改 | 增加第三个 Tab |
| `WebTestEntryView.swift` | ★ 新增 | Tab 根页面 |
| `WebTestNativeProbeView.swift` | ★ 新增 | 原生探针页 |
| `webtest.html` / `webtest-style.css` | ★ 新增 | 本地测试页资源 |
| `Package.swift`（WebContainerFeature） | ✎ 修改 | 声明 `resources` |
| `MyEcommerceApp.swift` | ✎ 修改 | 补充 `WebRouteFactory` / `NativeBridgeRouter` 注册 |

**新增文件 6 个，修改文件 8 个。**

---

## 8. 验收清单

- [ ] WebTest Tab 可正常显示，自动加载本地 `webtest.html`，页面样式、相对路径 CSS 正常渲染
- [ ] 点击「跳转原生测试页」→ push 到探针页，可正常返回
- [ ] 点击「弹出 Sheet」→ 以 Sheet 形式展示探针页，可正常 dismiss
- [ ] 输入任意 productId 点击「跳转商品详情页」→ 正确跳转到对应商品的真实详情页（验证参数透传）
- [ ] 输入不存在的 productId → 详情页内正常走"商品不存在"的现有错误处理（验证未额外引入新的错误路径）
- [ ] 「打开相机」「分享文本」「弹出 Alert」按钮均触发对应系统行为
- [ ] 自定义函数调用分组可成功将任意 JSON params 送达 `customFunctionHandlers`（可临时注册一个打印 log 的 handler 验证）
- [ ] 调用日志区（若实现 §4.3）能正确显示每次操作的 ack 状态

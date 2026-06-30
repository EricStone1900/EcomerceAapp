# WebContainer Feature — 实现计划

> 基于 `docs/specs/webcont-feature-plan.md`（v1.0）的详细实现步骤
> 适配 EcommerceAppDemo 现有 Clean Architecture + SPM 模式

---

## 0. Context / 背景

在现有电商 App 中新增 **WebContainer Feature**，具备三项能力：
1. **本地内容加载** — 加载 Bundle 内的 HTML 文件（含相对路径 JS/CSS/图片）
2. **远端 URL 加载** — 加载任意外部网页
3. **Web → Native Bridge** — Web 页面通过 JS 消息下发指令，按规则映射到原生界面或能力

**为什么需要这个计划：** 本功能涉及 4 层架构、约 25 个文件的新增/修改，需要严格对齐现有 Clean Architecture 模式（enum-based SPM targets、`extension DIContainer` 注册、ViewModel 内 resolve 依赖等）。

---

## Phase 1: SPM Target 注册（修改 4 个文件）
### 目标
在各个 Package.swift 中注册 WebContainer 对应的 SPM target，确保编译系统能发现新模块。

### 1.1 Abstraction — `Packages/Abstraction/Package.swift`
- **修改 `AbstractionProduct` 枚举**：新增 `case WebContainerAbstraction`
- **配置 path**：`"Sources/Abstraction/WebContainerAbstraction"`
- **dependencies**：仅依赖 `.external(.RxSwift)`（与其他 Abstraction 一致）
- **`AbstractionModule` 扩展**：在 Domain/Data/Presentation 的 `AbstractionModule` 枚举分别新增 `case WebContainerAbstraction`，映射到 `.product(name: "WebContainerAbstraction", package: "Abstraction")`

### 1.2 Domain — `Packages/Domain/Package.swift`
- **修改 `DomainProduct` 枚举**：新增 `case WebContainerDomain`
- **配置 path**：`"Sources/Domain/WebContainerDomain"`
- **dependencies**：`.external(.RxSwift)`, `.abstraction(.WebContainerAbstraction)`, `.abstraction(.DIAbstraction)`

### 1.3 Data — `Packages/Data/Package.swift`
- **修改 `DataProduct` 枚举**：新增 `case WebContainerData`
- **配置 path**：`"Sources/Data/WebContainerData"`
- **dependencies**：`.external(.RxSwift)`, `.abstraction(.WebContainerAbstraction)`, `.abstraction(.DIAbstraction)`

### 1.4 Presentation — 新建 `Packages/Presentation/WebContainerFeature/Package.swift`
- 独立 SPM 包（类似 `ProductsFeature` / `BasketFeature`）
- **Platfrom**：`.iOS(.v15)`（与现有项目一致）
- **Dependencies**：Abstraction（WebContainerAbstraction + DIAbstraction）、Domain（WebContainerDomain）、Utils、RxSwift、Swinject
- 单 target `WebContainerFeature`

---

## Phase 2: Abstraction 层 — 协议 & 领域模型（新建 10 个文件）

### 2.1 领域模型（6 个文件）

| 文件 | 说明 | 模式 |
|------|------|------|
| `DomainModel/WebContent.swift` | 加载目标的枚举：`.remoteURL(URL)`, `.localFile(fileName:bundle:)`, `.htmlString(String, baseURL:)` | `public enum` |
| `DomainModel/WebLoadInstruction.swift` | UseCase 输出枚举：`.loadRequest(URLRequest)`, `.loadFile(fileURL:accessURL:)`, `.loadHTML(html:baseURL:)` | `public enum` |
| `DomainModel/WebBridgeCommand.swift` | JS 消息解析结构体：`action: String`, `target: String?`, `params: [String: Any]` | `public struct` |
| `DomainModel/WebBridgeRule.swift` | 单条规则：`handlerName`, `action`, `target?`, `nativeAction`, `priority` | `public struct` |
| `DomainModel/NativeBridgeAction.swift` | 原生动作枚举：`.pushRoute()`, `.presentSheet()`, `.dismiss`, `.openCamera`, `.requestLocation`, `.shareContent()`, `.callFunction()`, `.showAlert()`, `.none` | `public enum` |
| `DomainModel/WebContainerError.swift` | 错误枚举：`.localFileNotFound(String)`, `.invalidURL`, `.bridgeMessageParseFailed` | `public enum Error` |

### 2.2 Repository 协议（2 个文件）

| 文件 | key 方法 |
|------|----------|
| `Repository/WebContentRepositoryProtocol.swift` | `func resolveInstruction(for content: WebContent) -> Observable<WebLoadInstruction>` |
| `Repository/WebBridgeRuleRepositoryProtocol.swift` | `func fetchRules() -> Observable<[WebBridgeRule]>`, `func registerRule(_ rule: WebBridgeRule)`, `func clearRules()` |

### 2.3 UseCase 协议（2 个文件）

| 文件 | key 方法 |
|------|----------|
| `UseCase/LoadWebContentUseCaseProtocol.swift` | `func execute(content: WebContent) -> Observable<WebLoadInstruction>` |
| `UseCase/ProcessBridgeCommandUseCaseProtocol.swift` | `func execute(command: WebBridgeCommand) -> Observable<NativeBridgeAction>` |

---

## Phase 3: Domain 层 — UseCase 实现（新建 3 个文件）

### 3.1 用例实现

| 文件 | 说明 |
|------|------|
| `LoadWebContentUseCase.swift` | 委托 `WebContentRepositoryProtocol` 解析指令，自身无业务逻辑 |
| `ProcessBridgeCommandUseCase.swift` | 按 `action + target` 精确匹配 → `action` 通配 → `.none` |

### 3.2 DI 注册

`DI/DIContainer+WebContainerDomain.swift` — 采用现有 `extension DIContainer` 模式：

```swift
import WebContainerAbstraction
import DIAbstraction

extension DIContainer {
    @MainActor
    public static func registerLoadWebContentUseCase() {
        DIContainer.shared.register(LoadWebContentUseCaseProtocol.self) { _ in
            let repo = DIContainer.shared.resolve(WebContentRepositoryProtocol.self)!
            return LoadWebContentUseCase(repository: repo)
        }
    }

    @MainActor
    public static func registerProcessBridgeCommandUseCase() {
        DIContainer.shared.register(ProcessBridgeCommandUseCaseProtocol.self) { _ in
            let ruleRepo = DIContainer.shared.resolve(WebBridgeRuleRepositoryProtocol.self)!
            return ProcessBridgeCommandUseCase(ruleRepository: ruleRepo)
        }
    }
}
```

---

## Phase 4: Data 层 — Repository & DataSource（新建 5 个文件）

### 4.1 DataSource

| 文件 | 说明 |
|------|------|
| `DataSource/LocalHTMLDataSource.swift` | 解析 Bundle 路径，返回 `(fileURL, accessURL)` 元组供 WKWebView 的 `loadFileURL(_:allowingReadAccessTo:)` |
| `DataSource/RemoteWebDataSource.swift` | 构建 URLRequest（注入 timeout / headers） |

### 4.2 Repository 实现

| 文件 | 说明 |
|------|------|
| `Repository/WebContentRepositoryImpl.swift` | switch `WebContent` 三种 case → 调用对应 DataSource → 返回 `WebLoadInstruction` |
| `Repository/WebBridgeRuleRepositoryImpl.swift` | In-Memory 存储 + 并发安全 |

### 4.3 DI 注册

`DI/DIContainer+WebContainerData.swift` — 现有 `extension DIContainer` 模式：

```swift
extension DIContainer {
    @MainActor
    public static func registerWebContainerData() {
        // 预注册初始 Bridge 规则
        let initialRules: [WebBridgeRule] = [
            WebBridgeRule(handlerName: "nativeBridge", action: "navigate",
                          target: "productDetail", nativeAction: .pushRoute("productDetail"), priority: 10),
            WebBridgeRule(handlerName: "nativeBridge", action: "openCamera",
                          target: nil, nativeAction: .openCamera, priority: 5),
            WebBridgeRule(handlerName: "nativeBridge", action: "dismiss",
                          target: nil, nativeAction: .dismiss, priority: 5),
        ]

        DIContainer.shared.register(WebBridgeRuleRepositoryProtocol.self) { _ in
            WebBridgeRuleRepositoryImpl(initialRules: initialRules)
        }.inObjectScope(.container)

        DIContainer.shared.register(WebContentRepositoryProtocol.self) { _ in
            WebContentRepositoryImpl()
        }
    }
}
```

---

## Phase 5: Presentation 层 — WebContainerFeature（新建 6 个文件）

### 5.1 ViewModel
`ViewModel/WebContainerViewModel.swift`

- **调整**：采用现有代码库模式 — 在 `init()` 内通过 `DIContainer.shared.resolve(...)` 获取依赖，而非构造函数注入
- `@Published` 状态：`isLoading`、`loadInstruction`、`error`
- 两个输入闭包：`loadWebContent(WebContent)`、`handleBridgeCommand(WebBridgeCommand)`
- RxSwift → Combine 桥接：`.asPublisher()`

### 5.2 View 层
| 文件 | 说明 |
|------|------|
| `View/WebContainerView.swift` | SwiftUI 入口：`WKWebViewRepresentable` + loading 蒙层 + 错误 alert |
| `View/WKWebViewRepresentable.swift` | `UIViewRepresentable`：注册 `WKUserContentController`、响应 `WebLoadInstruction` |

### 5.3 Bridge 层
| 文件 | 说明 |
|------|------|
| `Bridge/WebScriptMessageHandler.swift` | `WKScriptMessageHandler`：解析 JS 消息 → 组装 `WebBridgeCommand` → 回调 ViewModel |
| `Bridge/NativeBridgeRouter.swift` | 接收 `NativeBridgeAction` → 调用 UINavigationController 或系统能力 |

---

## Phase 6: App 入口注册（修改 1 个文件）

### `MyEcommerce/MyEcommerceApp.swift`
在 `init()` 注册列表末尾追加：
```swift
DIContainer.registerWebContainerData()
DIContainer.registerLoadWebContentUseCase()
DIContainer.registerProcessBridgeCommandUseCase()
```

---

## Phase 7: 验证方案

1. **编译检查**：`cd Packages/Abstraction && swift build` → `cd Packages/Domain && swift build` → `cd Packages/Data && swift build`
2. **Xcode 构建**：`xed .` 打开项目，确保 WebContainerFeature 包被正确解析
3. **单元测试（推荐后续）**：
   - `WebContentRepositoryImpl`：测试三种加载路径
   - `ProcessBridgeCommandUseCase`：测试精确匹配/通配/无匹配
   - `WebBridgeRuleRepositoryImpl`：测试线程安全+动态注册

---

## 关键调整清单（与原始 spec 的差异）

| 原始 spec 方案 | 实际采用方案 | 原因 |
|---------------|-------------|------|
| `WebContainerDomainDI` / `WebContainerDataDI` 独立 struct | `extension DIContainer` + `@MainActor public static func` | 与现有 ProductDomain、BasketDomain 等 DI 模式保持一致 |
| ViewModel 构造函数注入 | ViewModel `init()` 内 `DIContainer.shared.resolve(...)` | 与现有 ProductsListViewModel 等保持一致 |
| 作为 Abstraction 目标子目录 | 新增 `WebContainerAbstraction` enum case | 现有代码库使用枚举式分离目标 |
| `WebContainerError` 未定义 | 新增 `DomainModel/WebContainerError.swift` | LocalHTMLDataSource 引用了但未定义 |
| Platform `.iOS(.v16)` | `.iOS(.v15)` | 与项目其余部分一致 |

---

## 增量文件清单

### 修改已有（4 个）
- `Packages/Abstraction/Package.swift`
- `Packages/Domain/Package.swift`
- `Packages/Data/Package.swift`
- `MyEcommerce/MyEcommerceApp.swift`

### 新建（24 个）
- Abstraction: 10 个文件（6 DomainModel + 2 Repository + 2 UseCase）
- Domain: 3 个文件（2 UseCase + 1 DI）
- Data: 5 个文件（2 DataSource + 2 Repository + 1 DI）
- Presentation: 6 个文件（1 ViewModel + 2 View + 2 Bridge + 1 Package.swift）

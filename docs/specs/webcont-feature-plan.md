# WebContainer Feature — 实现计划

> 适配 EcommerceAppDemo 的 SPM 模块化 Clean Architecture
> 计划版本：v1.0

---

## 0. 背景与目标

在现有电商 App 中新增 **WebContainer** Feature，具备以下三项能力：

1. **本地内容加载** — 加载 Bundle 内的 HTML 文件（含相对路径的 JS/CSS/图片资源）
2. **远端 URL 加载** — 根据 URL 加载任意外部网页
3. **Web → Native Bridge** — Web 页面通过 JS 消息下发指令，按规则映射到原生界面或原生功能

---

## 1. 整体目录结构

新增文件以 `★` 标注，改动已有文件以 `✎` 标注。

```
Packages/
│
├── Abstraction/
│   └── Sources/Abstraction/
│       └── WebContainerAbstraction/          ★ 新增子目录
│           ├── DomainModel/
│           │   ├── WebContent.swift           ★ 加载目标（URL / 本地文件 / HTML字符串）
│           │   ├── WebLoadInstruction.swift   ★ Use Case 输出（WKWebView 加载指令）
│           │   ├── WebBridgeRule.swift        ★ 单条 Web→Native 映射规则
│           │   ├── WebBridgeCommand.swift     ★ JS 下发指令（解析后的结构体）
│           │   └── NativeBridgeAction.swift   ★ 原生动作枚举
│           ├── Repository/
│           │   ├── WebContentRepositoryProtocol.swift  ★
│           │   └── WebBridgeRuleRepositoryProtocol.swift ★
│           └── UseCase/
│               ├── LoadWebContentUseCaseProtocol.swift  ★
│               └── ProcessBridgeCommandUseCaseProtocol.swift ★
│
├── Domain/
│   └── Sources/Domain/
│       └── WebContainerDomain/               ★ 新增子目录
│           ├── LoadWebContentUseCase.swift    ★
│           ├── ProcessBridgeCommandUseCase.swift ★
│           └── DI/
│               └── WebContainerDomainDI.swift ★ 向 DIContainer 注册 Use Case
│
├── Data/
│   └── Sources/Data/
│       └── WebContainerData/                 ★ 新增子目录
│           ├── Repository/
│           │   ├── WebContentRepositoryImpl.swift   ★
│           │   └── WebBridgeRuleRepositoryImpl.swift ★
│           ├── DataSource/
│           │   ├── LocalHTMLDataSource.swift  ★ Bundle 资源读取
│           │   └── RemoteWebDataSource.swift  ★ 远端 URL 策略
│           └── DI/
│               └── WebContainerDataDI.swift   ★ 向 DIContainer 注册 Repository
│
├── Presentation/
│   └── WebContainerFeature/                  ★ 新增 SPM Package
│       ├── Package.swift                      ★
│       └── Sources/WebContainerFeature/
│           ├── ViewModel/
│           │   └── WebContainerViewModel.swift ★
│           ├── View/
│           │   ├── WebContainerView.swift      ★ SwiftUI 入口 View
│           │   └── WKWebViewRepresentable.swift ★ UIViewRepresentable
│           └── Bridge/
│               ├── WebScriptMessageHandler.swift ★ WKScriptMessageHandler
│               └── NativeBridgeRouter.swift      ★ 规则匹配结果 → 原生分发
│
└── (Utilities — 无需改动，复用现有 Utils 桥接)

MyEcommerce/
└── MyEcommerceApp.swift  ✎ 新增 WebContainer DI 注册调用
```

---

## 2. SPM Package 依赖声明

### 2.1 现有 Package.swift 改动

**`Packages/Domain/Package.swift`** — 已有，无需新建，只需确认 WebContainerDomain 作为 Domain target 的 Sources 子目录，无额外 target 声明。

**`Packages/Data/Package.swift`** — 同上，WebContainerData 自动归入 Data target。

**`Packages/Abstraction/Package.swift`** — 同上，WebContainerAbstraction 自动归入 Abstraction target。

### 2.2 新建 Package.swift

**`Packages/Presentation/WebContainerFeature/Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WebContainerFeature",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "WebContainerFeature", targets: ["WebContainerFeature"])
    ],
    dependencies: [
        .package(path: "../../Abstraction"),
        .package(path: "../../Domain"),
        .package(path: "../../Utilities/Utils"),
        // RxSwift — 与其他 Feature 保持一致版本
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "WebContainerFeature",
            dependencies: [
                "Abstraction",
                "Domain",
                "Utils",
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxCocoa", package: "RxSwift"),
            ]
        )
    ]
)
```

---

## 3. Abstraction 层 — 协议 & 领域模型

> 原则：零项目内依赖，只引入 RxSwift / Swinject。

### 3.1 领域模型（DomainModel/）

**`WebContent.swift`**

加载目标描述，覆盖三种场景，Use Case 统一消费：

```swift
// Abstraction 层，无 WKWebView 依赖
public enum WebContent {
    case remoteURL(URL)
    case localFile(fileName: String, bundle: Bundle = .main)
    case htmlString(String, baseURL: URL?)
}
```

**`WebLoadInstruction.swift`**

Use Case 的输出，对应 WKWebView 的三种加载方式，保持 Domain 层对 WebKit 的隔离：

```swift
public enum WebLoadInstruction {
    case loadRequest(URLRequest)
    case loadFile(fileURL: URL, accessURL: URL)   // 对应 loadFileURL(_:allowingReadAccessTo:)
    case loadHTML(html: String, baseURL: URL?)
}
```

**`WebBridgeCommand.swift`**

JS 下发的原始消息经解析后的标准结构：

```swift
public struct WebBridgeCommand {
    public let action: String               // e.g. "navigate"
    public let target: String?              // e.g. "productDetail"
    public let params: [String: Any]        // e.g. { "productId": "42" }
}
```

**`WebBridgeRule.swift`**

描述一条规则：什么消息 → 什么动作：

```swift
public struct WebBridgeRule {
    public let handlerName: String          // JS 消息名（固定为 "nativeBridge"）
    public let action: String               // 匹配 WebBridgeCommand.action
    public let target: String?              // nil 表示通配 target
    public let nativeAction: NativeBridgeAction
    public let priority: Int                // 数字越大优先级越高
}
```

**`NativeBridgeAction.swift`**

所有可触发的原生动作，随项目扩展持续添加枚举 case：

```swift
public enum NativeBridgeAction {
    // 导航
    case pushRoute(String)                  // 路由标识，由 NativeBridgeRouter 解析
    case presentSheet(String)
    case dismiss

    // 系统能力
    case openCamera
    case requestLocation
    case shareContent(String)

    // 通用
    case callFunction(name: String, params: [String: Any])
    case showAlert(title: String, message: String)
    case none                               // 无匹配，静默忽略
}
```

### 3.2 Repository 协议（Repository/）

**`WebContentRepositoryProtocol.swift`**

```swift
import RxSwift

public protocol WebContentRepositoryProtocol {
    /// 将 WebContent 解析为 WKWebView 可直接执行的加载指令
    func resolveInstruction(for content: WebContent) -> Observable<WebLoadInstruction>
}
```

**`WebBridgeRuleRepositoryProtocol.swift`**

```swift
import RxSwift

public protocol WebBridgeRuleRepositoryProtocol {
    func fetchRules() -> Observable<[WebBridgeRule]>
    func registerRule(_ rule: WebBridgeRule)
    func clearRules()
}
```

### 3.3 UseCase 协议（UseCase/）

**`LoadWebContentUseCaseProtocol.swift`**

```swift
import RxSwift

public protocol LoadWebContentUseCaseProtocol {
    func execute(content: WebContent) -> Observable<WebLoadInstruction>
}
```

**`ProcessBridgeCommandUseCaseProtocol.swift`**

```swift
import RxSwift

public protocol ProcessBridgeCommandUseCaseProtocol {
    func execute(command: WebBridgeCommand) -> Observable<NativeBridgeAction>
}
```

---

## 4. Domain 层 — UseCase 实现

> 依赖：Abstraction 协议 + RxSwift。不依赖 Data 实现。

### 4.1 `LoadWebContentUseCase.swift`

职责：接收 `WebContent`，委托 Repository 解析为 `WebLoadInstruction`。本身不含解析逻辑（解析在 Data 层 DataSource 中）：

```swift
import RxSwift
import Abstraction

public final class LoadWebContentUseCase: LoadWebContentUseCaseProtocol {
    private let repository: WebContentRepositoryProtocol

    public init(repository: WebContentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(content: WebContent) -> Observable<WebLoadInstruction> {
        repository.resolveInstruction(for: content)
    }
}
```

### 4.2 `ProcessBridgeCommandUseCase.swift`

职责：查询所有规则，按 `action + target` 精确匹配，降级为仅 `action` 通配匹配，无匹配返回 `.none`。规则匹配逻辑完全在 Domain 层，与 WebKit 解耦：

```swift
import RxSwift
import Abstraction

public final class ProcessBridgeCommandUseCase: ProcessBridgeCommandUseCaseProtocol {
    private let ruleRepository: WebBridgeRuleRepositoryProtocol

    public init(ruleRepository: WebBridgeRuleRepositoryProtocol) {
        self.ruleRepository = ruleRepository
    }

    public func execute(command: WebBridgeCommand) -> Observable<NativeBridgeAction> {
        ruleRepository.fetchRules().map { rules in
            let sorted = rules.sorted { $0.priority > $1.priority }

            // 1. 精确匹配（action + target）
            if let exact = sorted.first(where: {
                $0.action == command.action && $0.target == command.target
            }) { return exact.nativeAction }

            // 2. 通配匹配（action，target == nil）
            if let wildcard = sorted.first(where: {
                $0.action == command.action && $0.target == nil
            }) { return wildcard.nativeAction }

            // 3. 无匹配
            return .none
        }
    }
}
```

### 4.3 `DI/WebContainerDomainDI.swift`

与项目现有 DI 风格保持一致（静态注册方法 + DIContainer.shared）：

```swift
import Abstraction

public struct WebContainerDomainDI {
    public static func registerDependencies() {
        DIContainer.shared.register(LoadWebContentUseCaseProtocol.self) { resolver in
            LoadWebContentUseCase(
                repository: resolver.resolve(WebContentRepositoryProtocol.self)!
            )
        }
        DIContainer.shared.register(ProcessBridgeCommandUseCaseProtocol.self) { resolver in
            ProcessBridgeCommandUseCase(
                ruleRepository: resolver.resolve(WebBridgeRuleRepositoryProtocol.self)!
            )
        }
    }
}
```

---

## 5. Data 层 — Repository & DataSource 实现

> 依赖：Abstraction 协议 + Utilities/Networking（可选）。

### 5.1 DataSource

**`LocalHTMLDataSource.swift`**

处理 Bundle 文件路径解析和 WKWebView 沙箱限制（必须使用 `loadFileURL(_:allowingReadAccessTo:)`）：

```swift
import Foundation

public struct LocalHTMLDataSource {
    /// 返回 (fileURL, accessURL) — WKWebView 的双路径需求
    public func resolve(fileName: String, bundle: Bundle) throws -> (fileURL: URL, accessURL: URL) {
        // 1. 获取文件完整路径（含扩展名）
        let nameOnly = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.isEmpty ? "html"
                  : (fileName as NSString).pathExtension

        guard let fileURL = bundle.url(forResource: nameOnly, withExtension: ext) else {
            throw WebContainerError.localFileNotFound(fileName)
        }

        // 2. 授予上级目录访问权限，使相对路径的 JS/CSS/图片能正常加载
        let accessURL = fileURL.deletingLastPathComponent()
        return (fileURL, accessURL)
    }
}
```

**`RemoteWebDataSource.swift`**

统一注入 Header / Cookie / 超时策略，与现有 `APIProvider` 不重叠（WebContainer 加载的是完整网页，不是 JSON API）：

```swift
import Foundation

public struct RemoteWebDataSource {
    private let timeoutInterval: TimeInterval
    private let additionalHeaders: [String: String]

    public init(
        timeoutInterval: TimeInterval = 30,
        additionalHeaders: [String: String] = [:]
    ) {
        self.timeoutInterval = timeoutInterval
        self.additionalHeaders = additionalHeaders
    }

    public func buildRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        additionalHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
}
```

### 5.2 Repository 实现

**`WebContentRepositoryImpl.swift`**

```swift
import RxSwift
import Abstraction

public final class WebContentRepositoryImpl: WebContentRepositoryProtocol {
    private let localSource: LocalHTMLDataSource
    private let remoteSource: RemoteWebDataSource

    public init(
        localSource: LocalHTMLDataSource = .init(),
        remoteSource: RemoteWebDataSource = .init()
    ) {
        self.localSource = localSource
        self.remoteSource = remoteSource
    }

    public func resolveInstruction(for content: WebContent) -> Observable<WebLoadInstruction> {
        Observable.create { observer in
            do {
                let instruction: WebLoadInstruction
                switch content {
                case .remoteURL(let url):
                    let request = self.remoteSource.buildRequest(for: url)
                    instruction = .loadRequest(request)
                case .localFile(let name, let bundle):
                    let (fileURL, accessURL) = try self.localSource.resolve(
                        fileName: name, bundle: bundle
                    )
                    instruction = .loadFile(fileURL: fileURL, accessURL: accessURL)
                case .htmlString(let html, let baseURL):
                    instruction = .loadHTML(html: html, baseURL: baseURL)
                }
                observer.onNext(instruction)
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }
}
```

**`WebBridgeRuleRepositoryImpl.swift`**

In-Memory 存储，线程安全（通过 serial queue）：

```swift
import RxSwift
import Abstraction

public final class WebBridgeRuleRepositoryImpl: WebBridgeRuleRepositoryProtocol {
    private var rules: [WebBridgeRule] = []
    private let queue = DispatchQueue(label: "com.app.webbridge.rules", attributes: .concurrent)

    public init(initialRules: [WebBridgeRule] = []) {
        self.rules = initialRules
    }

    public func fetchRules() -> Observable<[WebBridgeRule]> {
        Observable.create { [weak self] observer in
            self?.queue.sync {
                observer.onNext(self?.rules ?? [])
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }

    public func registerRule(_ rule: WebBridgeRule) {
        queue.async(flags: .barrier) { self.rules.append(rule) }
    }

    public func clearRules() {
        queue.async(flags: .barrier) { self.rules.removeAll() }
    }
}
```

### 5.3 `DI/WebContainerDataDI.swift`

```swift
import Abstraction

public struct WebContainerDataDI {
    public static func registerDependencies() {
        // 预注册一批初始 Bridge 规则
        let initialRules: [WebBridgeRule] = [
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "navigate",
                target: "productDetail",
                nativeAction: .pushRoute("productDetail"),
                priority: 10
            ),
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "openCamera",
                target: nil,
                nativeAction: .openCamera,
                priority: 5
            ),
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "dismiss",
                target: nil,
                nativeAction: .dismiss,
                priority: 5
            ),
        ]

        DIContainer.shared.register(WebBridgeRuleRepositoryProtocol.self) { _ in
            WebBridgeRuleRepositoryImpl(initialRules: initialRules)
        }.inObjectScope(.container)   // 单例：规则跨 WebContainer 实例共享

        DIContainer.shared.register(WebContentRepositoryProtocol.self) { _ in
            WebContentRepositoryImpl()
        }
    }
}
```

---

## 6. Presentation 层 — WebContainerFeature

> 依赖：Abstraction + Domain + Utilities/Utils（RxSwift → Combine 桥接）。

### 6.1 `ViewModel/WebContainerViewModel.swift`

与项目其他 ViewModel 风格保持一致：RxSwift 在 Use Case 侧，Combine `@Published` 在 View 侧，通过 `Utils` 的 `asPublisher()` 桥接：

```swift
import Combine
import RxSwift
import Abstraction

public final class WebContainerViewModel: ObservableObject {
    // MARK: — Published State（驱动 SwiftUI View）
    @Published public var isLoading: Bool = false
    @Published public var loadInstruction: WebLoadInstruction? = nil
    @Published public var error: Error? = nil

    // MARK: — Inputs
    public let loadWebContent: (WebContent) -> Void
    public let handleBridgeCommand: (WebBridgeCommand) -> Void

    private let disposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()

    public init(
        loadUseCase: LoadWebContentUseCaseProtocol,
        bridgeUseCase: ProcessBridgeCommandUseCaseProtocol,
        bridgeRouter: NativeBridgeRouter
    ) {
        // — loadWebContent closure
        let loadSubject = PublishSubject<WebContent>()
        loadWebContent = { loadSubject.onNext($0) }

        loadSubject
            .do(onNext: { [weak self] _ in self?.isLoading = true })
            .flatMapLatest { loadUseCase.execute(content: $0) }
            .observe(on: MainScheduler.instance)
            .asPublisher()                             // Utils 桥接
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let err) = completion { self?.error = err }
                },
                receiveValue: { [weak self] instruction in
                    self?.isLoading = false
                    self?.loadInstruction = instruction
                }
            )
            .store(in: &cancellables)

        // — handleBridgeCommand closure
        let bridgeSubject = PublishSubject<WebBridgeCommand>()
        handleBridgeCommand = { bridgeSubject.onNext($0) }

        bridgeSubject
            .flatMapLatest { bridgeUseCase.execute(command: $0) }
            .observe(on: MainScheduler.instance)
            .asPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { action in bridgeRouter.dispatch(action) }
            )
            .store(in: &cancellables)
    }
}
```

### 6.2 `View/WKWebViewRepresentable.swift`

UIViewRepresentable 桥接，持有 WKWebView 实例，响应 ViewModel 的 `loadInstruction`：

```swift
import SwiftUI
import WebKit
import Abstraction

public struct WKWebViewRepresentable: UIViewRepresentable {
    private let messageHandler: WebScriptMessageHandler
    @Binding var instruction: WebLoadInstruction?

    public init(
        messageHandler: WebScriptMessageHandler,
        instruction: Binding<WebLoadInstruction?>
    ) {
        self.messageHandler = messageHandler
        self._instruction = instruction
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // 注册固定消息通道名 "nativeBridge"
        config.userContentController.add(messageHandler, name: "nativeBridge")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        guard let instruction else { return }
        switch instruction {
        case .loadRequest(let request):
            webView.load(request)
        case .loadFile(let fileURL, let accessURL):
            webView.loadFileURL(fileURL, allowingReadAccessTo: accessURL)
        case .loadHTML(let html, let baseURL):
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator: NSObject, WKNavigationDelegate {
        // 可在此处理 navigationDelegate 回调（页面加载进度、错误等）
    }
}
```

### 6.3 `View/WebContainerView.swift`

SwiftUI 入口，供 App 内任何地方调用：

```swift
import SwiftUI
import Abstraction

public struct WebContainerView: View {
    @ObservedObject private var viewModel: WebContainerViewModel
    private let messageHandler: WebScriptMessageHandler

    public init(viewModel: WebContainerViewModel, messageHandler: WebScriptMessageHandler) {
        self.viewModel = viewModel
        self.messageHandler = messageHandler
    }

    public var body: some View {
        ZStack {
            WKWebViewRepresentable(
                messageHandler: messageHandler,
                instruction: $viewModel.loadInstruction
            )

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .alert(
            "加载失败",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            ),
            actions: { Button("确认", role: .cancel) {} },
            message: { Text(viewModel.error?.localizedDescription ?? "") }
        )
    }
}
```

### 6.4 `Bridge/WebScriptMessageHandler.swift`

WKScriptMessageHandler 实现，是 WebKit → Domain 的唯一入口，只做格式解析，不做业务判断：

```swift
import WebKit
import Abstraction

public final class WebScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let onCommand: (WebBridgeCommand) -> Void

    public init(onCommand: @escaping (WebBridgeCommand) -> Void) {
        self.onCommand = onCommand
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "nativeBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String
        else { return }

        let command = WebBridgeCommand(
            action: action,
            target: body["target"] as? String,
            params: body["params"] as? [String: Any] ?? [:]
        )
        onCommand(command)
    }
}
```

### 6.5 `Bridge/NativeBridgeRouter.swift`

接收 `NativeBridgeAction`，调用 App 现有导航体系（`TabRouter` / `NavigationPath` / Coordinator），集中管理所有原生跳转与能力调用：

```swift
import Abstraction
import UIKit

public final class NativeBridgeRouter {
    // 注入现有 App 导航入口，与 TabRouter 协作
    private weak var navigationController: UINavigationController?
    private let routeResolver: (String) -> UIViewController?

    public init(
        navigationController: UINavigationController?,
        routeResolver: @escaping (String) -> UIViewController?
    ) {
        self.navigationController = navigationController
        self.routeResolver = routeResolver
    }

    public func dispatch(_ action: NativeBridgeAction) {
        switch action {
        case .pushRoute(let route):
            guard let vc = routeResolver(route) else { return }
            navigationController?.pushViewController(vc, animated: true)
        case .presentSheet(let route):
            guard let vc = routeResolver(route) else { return }
            vc.modalPresentationStyle = .pageSheet
            navigationController?.present(vc, animated: true)
        case .dismiss:
            navigationController?.dismiss(animated: true)
        case .openCamera:
            // 调用现有相机模块入口
            break
        case .requestLocation:
            // 调用现有定位模块入口
            break
        case .shareContent(let text):
            let activity = UIActivityViewController(
                activityItems: [text], applicationActivities: nil
            )
            navigationController?.present(activity, animated: true)
        case .showAlert(let title, let message):
            let alert = UIAlertController(
                title: title, message: message, preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确认", style: .default))
            navigationController?.present(alert, animated: true)
        case .callFunction(let name, let params):
            // 扩展点：注册自定义函数处理器
            customFunctionHandlers[name]?(params)
        case .none:
            break
        }
    }

    // 运行时可注册自定义函数处理器
    private var customFunctionHandlers: [String: ([String: Any]) -> Void] = [:]

    public func registerFunction(name: String, handler: @escaping ([String: Any]) -> Void) {
        customFunctionHandlers[name] = handler
    }
}
```

---

## 7. DI 注册接入 — App 入口改动

**`MyEcommerce/MyEcommerceApp.swift`**

在现有注册调用列表末尾追加两行：

```swift
@main
struct MyEcommerceApp: App {
    init() {
        // —— 现有注册 ——
        ProductDataDI.registerDependencies()
        ProductDomainDI.registerDependencies()
        BasketDataDI.registerDependencies()
        BasketDomainDI.registerDependencies()
        UserDataDI.registerDependencies()
        UserDomainDI.registerDependencies()
        AnalyticsDomainDI.registerDependencies()

        // —— 新增：WebContainer ——
        WebContainerDataDI.registerDependencies()    // ★ Data 先于 Domain 注册
        WebContainerDomainDI.registerDependencies()  // ★
    }
    // ...
}
```

---

## 8. 使用方式（调用示例）

### 8.1 加载远端 URL

```swift
let viewModel = DIContainer.shared.resolve(WebContainerViewModel.self)!
viewModel.loadWebContent(.remoteURL(URL(string: "https://example.com/promo")!))

// 在 SwiftUI 中
WebContainerView(viewModel: viewModel, messageHandler: messageHandler)
```

### 8.2 加载本地 HTML

```swift
viewModel.loadWebContent(.localFile(fileName: "campaign.html", bundle: .main))
// 前提：campaign.html + 同级 css/js 资源在 Bundle 内
```

### 8.3 Web → Native 消息（JS 侧）

```javascript
// Web 页面内通过以下固定格式下发指令
window.webkit.messageHandlers.nativeBridge.postMessage({
  action: "navigate",
  target: "productDetail",
  params: { productId: "42" }
});

window.webkit.messageHandlers.nativeBridge.postMessage({
  action: "openCamera"
  // target 省略 → 命中通配规则
});
```

### 8.4 运行时注册新规则

```swift
let ruleRepo = DIContainer.shared.resolve(WebBridgeRuleRepositoryProtocol.self)!
ruleRepo.registerRule(WebBridgeRule(
    handlerName: "nativeBridge",
    action: "openMemberCard",
    target: nil,
    nativeAction: .pushRoute("memberCard"),
    priority: 8
))
```

---

## 9. 分层依赖总结

```
WebContainerFeature (Presentation)
    ↓ 依赖
Abstraction（协议 + 模型）← WebContainerData（Data）
    ↓ 依赖
WebContainerDomain（Domain）
    ↓ 依赖
Abstraction（协议 + 模型）

Utilities/Utils（RxSwift → Combine 桥接）由 Presentation 层引用，不变
```

| 包 / 模块 | 新增内容 | 外部依赖 |
|---|---|---|
| Abstraction | WebContainerAbstraction（5个文件） | RxSwift、Swinject（已有） |
| Domain | WebContainerDomain（3个文件） | Abstraction、RxSwift |
| Data | WebContainerData（5个文件） | Abstraction、RxSwift |
| Presentation/WebContainerFeature | 6个文件 + Package.swift | Abstraction、Domain、Utils |
| MyEcommerceApp.swift | +2行注册调用 | — |

**总计新增文件：21 个，改动已有文件：1 个。**

---

## 10. 关键决策说明

**为什么 `WebLoadInstruction` 放在 Abstraction 而不是 Data？**
Use Case 的返回值需要跨越 Domain → Presentation 传递，若放在 Data 层会造成 Presentation 反向依赖 Data，违反依赖规则。放在 Abstraction 层，所有层均可引用。

**为什么不复用 `Networking/APIProvider`？**
`APIProvider` 专为 JSON API 设计（请求→解析→DTO→模型映射），WebContainer 加载的是完整网页，流程完全不同。`RemoteWebDataSource` 只做 `URLRequest` 构建，更轻量，职责清晰。

**Bridge 规则匹配为何在 Domain 层而非 Presentation？**
规则映射是业务决策（"哪个 Web 指令对应哪个原生能力"），属于业务逻辑范畴。放在 Domain 层后，未来更换 WebView 实现（如 LKWebView / 自研渲染器）时规则层无需改动，测试也更简单（纯 Swift 单测，不需要 WebKit 环境）。

**`WebBridgeRuleRepositoryImpl` 为什么注册为 `.inObjectScope(.container)`（单例）？**
Bridge 规则需要在 App 运行期间持续共享，且支持运行时动态注册新规则。若每次创建 WebContainerView 都重建 Repository，动态注册的规则就会丢失。

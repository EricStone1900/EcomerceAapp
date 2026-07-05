# Stage 4: 实现 PresentationCore — BaseHostingController / BaseNavigationController

## Context

阶段 1-3 完成了从协议定义到路由跳转的整条链路。本阶段在 Utilities 层新建 `PresentationCore` 包，提供两个 UIKit 基类实现**横切关注点**的自动处理：

1. **页面停留时长自动埋点** — 所有 `BaseHostingController` 子类无需手动编写埋点代码
2. **统一导航栏 UI** — `BaseNavigationController` 集中配置设计规范样式

## 架构约束

关键原则：**Data 层不能依赖 Utilities 层**。因此：
- `AppRouter`（Data 层）不直接引用 `BaseHostingController`
- `BaseHostingController` 的自动埋点通过自己的 `viewWillAppear`/`viewWillDisappear` 生命周期钩子完成，不依赖 AppRouter
- `BaseNavigationController` 通过 App 层 DI 注册时传入 AppRouter，而非由 AppRouter 直接创建

## 修改文件

### 1. `Packages/Abstraction/Sources/Abstraction/RoutingAbstraction/PageLifecycleTrackable.swift`
已有此协议，无需修改。BaseHostingController 会在运行时检查 `self` 是否 `is PageLifecycleTrackable`。

### 2. `MyEcommerce/MyEcommerceApp.swift`（后续联调阶段，本阶段仅记录）
需要新增 `DIContainer.registerTrackPageLifecycleUseCase()` 调用。

## 新增文件（PresentationCore 包，5 个）

### 包结构：
```
Packages/Utilities/PresentationCore/
  Package.swift
  Sources/PresentationCore/
    BaseHostingController.swift
    BaseNavigationController.swift
    PageLifecycleTrackable+Default.swift
    DI/PresentationCoreAssembly.swift
```

### 3. `Packages/Utilities/PresentationCore/Package.swift`

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PresentationCore",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "PresentationCore",
            targets: ["PresentationCore"]
        ),
    ],
    dependencies: [
        .package(path: "../../Abstraction"),
        .package(url: "https://github.com/Swinject/Swinject", .upToNextMajor(from: "2.9.1")),
    ],
    targets: [
        .target(
            name: "PresentationCore",
            dependencies: [
                .product(name: "RoutingAbstraction", package: "Abstraction"),
                .product(name: "AnalyticsAbstraction", package: "Abstraction"),
                .product(name: "DIAbstraction", package: "Abstraction"),
                .product(name: "Swinject", package: "Swinject"),
            ]
        ),
    ]
)
```

### 4. `Sources/PresentationCore/BaseHostingController.swift`

```swift
/// UIHostingController 基类，自动处理：
/// 1. 页面停留时长埋点（viewWillAppear → viewWillDisappear）
/// 2. RouteBackButtonConfiguration 应用
/// 3. RouteTitleConfiguration 应用
///
/// 业务方无需编写任何额外代码即可获得这些横切能力。
open class BaseHostingController<Content: View>: UIHostingController<Content> {

    private var entryTimestamp: Date?
    private var pageIdentifier: String?

    /// 设置页面标识符（用于埋点降级兜底）
    /// 当页面未实现 PageLifecycleTrackable 时使用此值。
    public func setPageIdentifier(_ identifier: String) {
        pageIdentifier = identifier
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        entryTimestamp = Date()
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        trackPageLifecycle()
    }

    /// 调用 TrackPageLifecycleUseCaseProtocol 发送埋点。
    /// - 若 self 实现了 PageLifecycleTrackable，使用其 analyticsPageIdentifier
    /// - 否则使用 pageIdentifier（兜底值）
    /// - 均不存在时为 "unknown_page"
    private func trackPageLifecycle() {
        guard let entryTimestamp else { return }
        let duration = Date().timeIntervalSince(entryTimestamp)

        let identifier: String = {
            if let trackable = self as? PageLifecycleTrackable {
                return trackable.analyticsPageIdentifier
            }
            return pageIdentifier ?? "unknown_page"
        }()

        let extraParams: [String: Any]? = (self as? PageLifecycleTrackable)?.analyticsExtraParameters

        let useCase = DIContainer.shared.resolve(TrackPageLifecycleUseCaseProtocol.self)
        useCase?.start(pageIdentifier: identifier, duration: duration, extraParameters: extraParams)
    }
}
```

### 5. `Sources/PresentationCore/BaseNavigationController.swift`

```swift
/// UINavigationController 基类，统一配置导航栏外观。
///
/// 所有通过路由框架创建的页面共享同一套 UI 规范：
/// - 标题字体/颜色
/// - 返回箭头图标
/// - 分割线
/// - Bar 按钮样式
///
/// 修改此处样式即可全局生效，无需逐页修改。
open class BaseNavigationController: UINavigationController {

    open override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
    }

    /// 配置统一导航栏外观。
    /// 子类可覆写此方法自定义样式。
    open func configureAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        // 标题样式
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.label,
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor.label,
        ]

        // 返回按钮样式
        let backImage = UIImage(systemName: "chevron.left")
        appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)

        // 应用外观
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance

        // Bar 按钮样式
        navigationBar.tintColor = .systemBlue
    }
}
```

### 6. `Sources/PresentationCore/PageLifecycleTrackable+Default.swift`

此文件提供 `PageLifecycleTrackable` 的默认实现扩展，使业务页面可选择性继承默认值。

```swift
/// PageLifecycleTrackable 默认实现。
/// 若业务页面仅需提供页面标识符（无需额外参数），可仅实现 analyticsPageIdentifier，
/// analyticsExtraParameters 默认返回 nil。
extension PageLifecycleTrackable {
    public var analyticsExtraParameters: [String: Any]? { nil }
}
```

> 注意：此扩展已存在于 `RoutingAbstraction/PageLifecycleTrackable.swift`，此处仅为文档性引用。

### 7. `Sources/PresentationCore/DI/PresentationCoreAssembly.swift`

```swift
/// PresentationCore DI 注册。
/// 注册基类运行时所需依赖的解析方式。
extension DIContainer {

    /// 注册 PresentationCore 所需的依赖。
    /// 需在其他模块（如 AnalyticsDomain）完成 UseCase 注册后调用。
    @MainActor
    public static func registerPresentationCore() {
        // BaseHostingController 在 trackPageLifecycle() 中
        // 通过 DIContainer.shared.resolve(TrackPageLifecycleUseCaseProtocol.self)
        // 直接解析，无需预先注册。
        //
        // 但需确保 `DIContainer.registerTrackPageLifecycleUseCase()`
        // 在 App 启动时已被调用。
    }
}
```

> 注意：`BaseHostingController.trackPageLifecycle()` 中使用 `DIContainer.shared.resolve(TrackPageLifecycleUseCaseProtocol.self)` 的方式，与项目现有 ViewModel 的 Service Locator 模式完全一致。

## 不需要修改 AppRouter 的理由

架构约束决定 **Data 层不能依赖 Utilities 层**，因此：
- `AppRouter`（Data/RoutingData）保持现有 UIKit 通用 API 调用（`navigationItem.hidesBackButton`、`viewController.title`）
- `BaseHostingController`（Utilities/PresentationCore）通过自己的生命周期钩子独立处理埋点
- 两者通过 `UINavigationController` / `UIViewController` 这些 UIKit 公共契约间接协作
- App 层在组装时传入 `BaseNavigationController` 实例即可

## 执行顺序

1. `Packages/Utilities/PresentationCore/Package.swift`
2. `BaseNavigationController.swift`
3. `BaseHostingController.swift`
4. `PageLifecycleTrackable+Default.swift`
5. `DI/PresentationCoreAssembly.swift`
6. 验证：`cd Packages/Utilities/PresentationCore && swift build`

## 验收清单

- [ ] PresentationCore 包可独立编译
- [ ] BaseHostingController 在 viewWillAppear 记录时间戳，viewWillDisappear 计算时长并调用 TrackPageLifecycleUseCaseProtocol
- [ ] 未实现 PageLifecycleTrackable 的页面使用 pageIdentifier 兜底值，不崩溃
- [ ] 实现了 PageLifecycleTrackable 的页面使用自定义标识符
- [ ] BaseNavigationController.configureAppearance() 可被子类覆写
- [ ] 依赖仅限 RoutingAbstraction、AnalyticsAbstraction、DIAbstraction、Swinject

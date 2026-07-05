# Stage 3: 实现 RoutingData — push / present + 智能返回按钮

## Context

阶段 1 定义了路由协议（`RoutingAbstraction`），阶段 2 实现了跳转编排（`NavigateUseCase`）。本阶段在 Data 层实现真正的路由跳转能力：`AppRouter` 将 `AppRoute` 解析为 `UIViewController` 并执行 UIKit push/present，同时通过导航元数据栈实现"智能返回"——push 进去的页面自动 `popViewController`，present 进去的自动 `dismiss`。

## 设计概要

### RouteFactoryRegistry
持有多个 `RouteFactoryProtocol` 实例的容器。遍历注册的工厂，通过 `canHandle()` 找到第一个能处理目标路由的工厂，调用 `makeViewController(for:)` 产出 UIViewController。

### AppRouter（实现 RouterProtocol）
- 持有根 `UINavigationController` 和 `UITabBarController` 的弱引用（避免循环引用）
- 内部维护 `[NavigationType]` 元数据栈（`.push` / `.present`）
- `navigate(to:configuration:)`：通过 RouteFactoryRegistry 解析 VC → 根据 presentationStyle 执行 push 或 present → 记录元数据 → 应用返回按钮配置
- `goBack(animated:)`：从元数据栈 pop 最后一条记录 → push 走 `popViewController`，present 走 `dismiss`

## 修改文件

### 1. `Packages/Data/Package.swift`
- `DataProduct` 枚举新增 `case RoutingData`
- `AbstractionModule` 枚举新增 `case RoutingAbstraction` 及其 dependency 映射
- RoutingData 的 dependencies：`[.abstraction(.RoutingAbstraction), .abstraction(.DIAbstraction)]`（无 RxSwift）
- testsTargets 跳过（同 WebContainerData）

## 新增文件（3 个）

### 2. `Sources/Data/RoutingData/RouteFactoryRegistry.swift`

```swift
import Foundation
import RoutingAbstraction
import UIKit

/// 路由工厂注册中心。
/// 持有多个 RouteFactoryProtocol 实例，遍历匹配目标路由并产出 UIViewController。
///
/// App 启动时在此注册各业务模块的工厂，跳转时自动遍历匹配。
public final class RouteFactoryRegistry {

    private var factories: [RouteFactoryProtocol] = []

    public init() {}

    /// 注册一个路由工厂。
    public func registerFactory(_ factory: RouteFactoryProtocol) {
        factories.append(factory)
    }

    /// 遍历所有已注册工厂，找到第一个能处理该路由的工厂并创建 ViewController。
    /// - Parameter route: 目标路由
    /// - Returns: 目标 ViewController，无可处理工厂时返回 nil
    public func viewController(for route: AppRoute) -> UIViewController? {
        for factory in factories where factory.canHandle(route) {
            return factory.makeViewController(for: route)
        }
        return nil
    }
}
```

### 3. `Sources/Data/RoutingData/AppRouter.swift`

```swift
import Foundation
import RoutingAbstraction
import UIKit

/// 应用级导航路由器。
/// 实现 RouterProtocol，负责：
/// - 将 AppRoute 解析为 UIViewController 并执行 push/present
/// - 维护导航元数据栈，使 goBack 能智能选择 pop 或 dismiss
/// - 应用 RouteBackButtonConfiguration
///
/// 对 UINavigationController/UITabBarController 使用弱引用，避免循环引用。
public final class AppRouter: RouterProtocol {

    private weak var navigationController: UINavigationController?
    private weak var tabBarController: UITabBarController?
    private let factoryRegistry: RouteFactoryRegistry

    /// 导航元数据栈。每次 navigate 记录一条，goBack 时 pop。
    private var navigationMetadata: [NavigationType] = []

    private enum NavigationType {
        case push
        case present
    }

    public init(
        navigationController: UINavigationController?,
        tabBarController: UITabBarController?,
        factoryRegistry: RouteFactoryRegistry
    ) {
        self.navigationController = navigationController
        self.tabBarController = tabBarController
        self.factoryRegistry = factoryRegistry
    }

    // MARK: - RouterProtocol

    public func navigate(to route: AppRoute, configuration: RouteConfiguration) {
        guard let viewController = factoryRegistry.viewController(for: route) else { return }

        applyBarVisibilityIfNeeded(configuration.barVisibility)
        applyTitleIfNeeded(configuration.titleConfiguration, to: viewController)

        let style = configuration.presentationStyle ?? .push

        switch style {
        case .push:
            navigationController?.pushViewController(viewController, animated: true)
            navigationMetadata.append(.push)

        case .present(let modalStyle):
            viewController.modalPresentationStyle = modalStyle.toUIModalPresentationStyle()
            let presenting = navigationController ?? topmostViewController()
            presenting.present(viewController, animated: true)
            navigationMetadata.append(.present)
        }

        applyBackButtonConfiguration(configuration.backButton, to: viewController)
    }

    public func goBack(animated: Bool) {
        guard let lastType = navigationMetadata.popLast() else {
            // 元数据栈为空时退化为 pop（兼容未记录的场景）
            navigationController?.popViewController(animated: animated)
            return
        }

        switch lastType {
        case .push:
            navigationController?.popViewController(animated: animated)
        case .present:
            navigationController?.dismiss(animated: animated)
        }
    }

    // MARK: - Private Helpers

    private func applyBarVisibilityIfNeeded(_ config: RouteBarVisibilityConfiguration?) {
        guard let config = config else { return }
        let animated = config.animated ?? true
        if let hidesNavBar = config.hidesNavigationBar {
            navigationController?.setNavigationBarHidden(hidesNavBar, animated: animated)
        }
    }

    private func applyTitleIfNeeded(_ config: RouteTitleConfiguration?, to viewController: UIViewController) {
        guard let config = config else { return }
        switch config {
        case .text(let text):
            viewController.title = text
        case .attributedText(let attributedText):
            viewController.title = attributedText.string
        case .customTitleView:
            // 自定义 titleView 需要 navigationItem，待阶段 4 基类方案完整实现
            break
        }
    }

    private func applyBackButtonConfiguration(_ config: RouteBackButtonConfiguration?, to viewController: UIViewController) {
        guard let config = config else { return }

        switch config {
        case .systemDefault:
            viewController.navigationItem.hidesBackButton = false

        case .hidden:
            viewController.navigationItem.hidesBackButton = true

        case .custom(let title, _):
            viewController.navigationItem.hidesBackButton = false
            if let title {
                let backItem = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
                viewController.navigationItem.backBarButtonItem = backItem
            }
        }
    }

    /// 获取当前最顶层的 ViewController，用于无导航栈时的降级展示。
    private func topmostViewController() -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return UIViewController() }

        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - RouteModalStyle → UIModalPresentationStyle

private extension RouteModalStyle {
    func toUIModalPresentationStyle() -> UIModalPresentationStyle {
        switch self {
        case .fullScreen:  return .fullScreen
        case .pageSheet:   return .pageSheet
        case .formSheet:   return .formSheet
        case .automatic:   return .automatic
        }
    }
}
```

### 4. `Sources/Data/RoutingData/DI/RoutingDataAssembly.swift`

```swift
import Foundation
import DIAbstraction
import RoutingAbstraction

extension DIContainer {

    /// 注册 RouteFactoryRegistry。
    /// 各业务模块在 App 启动时通过该单例注册自己的 RouteFactoryProtocol。
    @MainActor
    public static func registerRouteFactoryRegistry() {
        DIContainer.shared.register(RouteFactoryRegistry.self) { _ in
            RouteFactoryRegistry()
        }
    }

    /// 注册 AppRouter。
    /// 需先注册 RouteFactoryRegistry；navigationController 在 resolve 后通过 setter 注入。
    @MainActor
    public static func registerAppRouter() {
        DIContainer.shared.register(RouterProtocol.self) { resolver in
            let registry = resolver.resolve(RouteFactoryRegistry.self)!
            return AppRouter(
                navigationController: nil,
                tabBarController: nil,
                factoryRegistry: registry
            )
        }
    }
}
```

## 执行顺序

1. `Packages/Data/Package.swift` — 新增 RoutingData + RoutingAbstraction
2. `RouteFactoryRegistry.swift`
3. `AppRouter.swift`
4. `DI/RoutingDataAssembly.swift`
5. 验证：`cd Packages/Data && swift build` 编译通过

## 验收清单

- [ ] AppRouter 对 UINavigationController/UITabBarController 使用弱引用
- [ ] navigate(push) 执行 pushViewController + 记录 push 元数据
- [ ] navigate(present) 执行 present + 记录 present 元数据
- [ ] goBack 从元数据栈 pop → push 场景 popViewController，present 场景 dismiss
- [ ] 元数据栈为空时退化为 popViewController（兼容降级）
- [ ] backButton .hidden 正确设置 hidesBackButton = true
- [ ] backButton .custom 正确设置 backBarButtonItem
- [ ] `cd Packages/Data && swift build` 编译通过

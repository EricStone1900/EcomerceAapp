# Stage 1: 实现 RoutingAbstraction（协议与配置模型）

## Context

项目目前的路由是特化为 WebContainer 场景的：`WebRouteFactoryProtocol` 使用字符串 + `[String: Any]` 字典作为路由标识，`NativeBridgeAction` 用枚举 case 硬编码 push/present 行为，缺少统一的配置模型。需要一个全局的路由协议层作为项目所有跳转场景的公共契约。

本阶段创建 `RoutingAbstraction` SPM 包（作为现有 `Abstraction` 伞包下的新 target），**只定义协议/枚举/结构体，不包含任何实现逻辑**，为后续的 Domain Navigation UseCase、Analytics 页面停留埋点等阶段提供基础。

## 修改文件

### 1. `Packages/Abstraction/Package.swift`
在 `AbstractionProduct` 枚举中新增 `case RoutingAbstraction`，定义其 dependencies 为 `[.external(.Swinject)]`。由于 UIKit 是系统框架，无需在 Package.swift 中声明。参考 `DIAbstraction` 仅依赖 Swinject 的模式。tests 参照 `WebContainerAbstraction` 跳过（`return []`）。

## 新增文件（12 个）

目录结构：
```
Sources/Abstraction/RoutingAbstraction/
  DomainModel/
    AppRoute.swift
    RoutePresentationStyle.swift
    RouteModalStyle.swift
    RouteTransition.swift
    RouteBackButtonConfiguration.swift
    RouteBarVisibilityConfiguration.swift
    RouteTitleConfiguration.swift
    RouteTitleViewProviding.swift
    RouteConfiguration.swift
  Repository/
    RouteFactoryProtocol.swift
    RouterProtocol.swift
  PageLifecycleTrackable.swift
```

### 1. `DomainModel/AppRoute.swift`
```swift
import Foundation

/// 路由标记协议。所有业务 Feature 的具体路由值需遵循此协议。
public protocol AppRoute {
}
```

### 2. `DomainModel/RouteModalStyle.swift`
```swift
import Foundation

/// 模态展示样式，对应 iOS UIModalPresentationStyle 的抽象。
public enum RouteModalStyle {
    case fullScreen
    case pageSheet
    case formSheet
    case automatic
}
```

### 3. `DomainModel/RoutePresentationStyle.swift`
```swift
import Foundation

/// 页面展示样式：推入导航栈或模态展示。
public enum RoutePresentationStyle {
    case push
    case present(modal: RouteModalStyle)
}
```

### 4. `DomainModel/RouteTransition.swift`
定义 `RouteTransition`（系统默认 / 系统预置 / 自定义）、`RouteSystemTransition`（fade/slideLeft/slideRight/slideUp/slideDown/flipHorizontal/crossDissolve）、以及 `RouteAnimatorProviding` 协议（标记协议，继承 `UIViewControllerAnimatedTransitioning`）。

### 5. `DomainModel/RouteBackButtonConfiguration.swift`
```swift
public enum RouteBackButtonConfiguration {
    case systemDefault
    case hidden
    case custom(title: String?, image: UIImage?)
}
```

### 6. `DomainModel/RouteBarVisibilityConfiguration.swift`
```swift
public struct RouteBarVisibilityConfiguration {
    public var hidesNavigationBar: Bool?
    public var hidesTabBar: Bool?
    public var animated: Bool?
    public static let `default` = RouteBarVisibilityConfiguration()
    public init(hidesNavigationBar: Bool? = nil, hidesTabBar: Bool? = nil, animated: Bool? = nil)
}
```
所有属性为 Optional，nil 表示"不主动改变"。遵循 **all nil = system defaults** 模式。

### 7. `DomainModel/RouteTitleViewProviding.swift`
```swift
public protocol RouteTitleViewProviding: AnyObject {
    func makeTitleView() -> UIView
}
```

### 8. `DomainModel/RouteTitleConfiguration.swift`
```swift
public enum RouteTitleConfiguration {
    case text(String)
    case attributedText(NSAttributedString)
    case customTitleView(RouteTitleViewProviding)
}
```

### 9. `DomainModel/RouteConfiguration.swift`
配置聚合体，包含 5 个 Optional 属性，`.default` 静态属性 = 全 nil 实例。所有属性均遵循 **all nil = system defaults** 模式：
- `presentationStyle: RoutePresentationStyle?`
- `transition: RouteTransition?`
- `backButton: RouteBackButtonConfiguration?`
- `barVisibility: RouteBarVisibilityConfiguration?`
- `titleConfiguration: RouteTitleConfiguration?`

### 10. `Repository/RouteFactoryProtocol.swift`
```swift
public protocol RouteFactoryProtocol {
    func canHandle(_ route: AppRoute) -> Bool
    func makeViewController(for route: AppRoute) -> UIViewController?
}
```

### 11. `Repository/RouterProtocol.swift`
```swift
public protocol RouterProtocol {
    func navigate(to route: AppRoute, configuration: RouteConfiguration)
    func goBack(animated: Bool)
}
```

### 12. `PageLifecycleTrackable.swift`
```swift
public protocol PageLifecycleTrackable: AnyObject {
    var analyticsPageIdentifier: String { get }
    var analyticsExtraParameters: [String: Any]? { get }
}
```
为阶段 4（页面停留埋点 UseCase）预留。

## 关键设计决策

1. **all nil = system defaults 模式**：`RouteConfiguration` 和 `RouteBarVisibilityConfiguration` 的所有属性均为 Optional，nil 表示"不改变当前状态，走系统默认"。调用方可只传需要定制的属性。
2. **Swinject 依赖**：仅作为基础设施预留（后续 DI 注册用），本阶段不写任何 DI 注册代码。
3. **跳过测试**：参照 WebContainerAbstraction 模式，本阶段不创建测试 target。
4. **目录组织**：按照项目惯例，DomainModel 放模型类型，Repository 放协议。

## 验收清单

- [ ] 包可独立编译通过，无任何实现逻辑，只有协议/类型声明
- [ ] 未引入除 Swinject/UIKit 外的任何依赖
- [ ] `RouteConfiguration` 和 `RouteBarVisibilityConfiguration` 提供合理的默认值
- [ ] 所有类型命名清晰，中文注释说明每个协议的职责边界
- [ ] 验证方式：`cd Packages/Abstraction && swift build` 编译通过

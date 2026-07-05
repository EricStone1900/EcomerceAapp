# Stage 2: 实现 RoutingDomain + Analytics 埋点 UseCase 扩展

## Context

阶段 1 已完成 `RoutingAbstraction`（路由协议与配置模型）。本阶段在其上实现两层业务编排：
1. **RoutingDomain** — `NavigateUseCase` 作为路由跳转的业务编排层，依赖 `RoutingAbstraction` 的 `RouterProtocol`
2. **Analytics 扩展** — `TrackPageLifecycleUseCase` 作为页面停留埋点 UseCase，复用现有的 `AnalyticsWrapperProtocol` 基础设施

## 架构原则

- Domain 层仅依赖 Abstraction 协议，不 import UIKit
- 遵循现有 Domain UseCase 模式（创建 UseCaseProtocol → 实现 → DI 注册）
- 遵循现有 AnalyticsDomain 的同步（无 RxSwift）模式

## 修改文件

### 1. `Packages/Domain/Package.swift`
- `DomainProduct` 枚举新增 `case RoutingDomain`
- `AbstractionModule` 枚举新增 `case RoutingAbstraction`
- RoutingDomain 的 dependencies：`[.abstraction(.RoutingAbstraction), .abstraction(.DIAbstraction)]`
- test target 正常创建（非 WebContainerDomain 那样跳过）

### 2. `Packages/Abstraction/Sources/Abstraction/AnalyticsAbstraction/`
- 新增文件：`TrackPageLifecycleUseCaseProtocol.swift`

### 3. `Packages/Domain/Sources/Domain/AnalyticsDomain/DI/DI.swift`
- 新增 `registerTrackPageLifecycleUseCase()` 方法

## 新增文件

### 4. `Packages/Domain/Sources/Domain/RoutingDomain/Usecase/NavigateUseCase.swift`

```swift
import Foundation
import RoutingAbstraction
import DIAbstraction

public protocol NavigateUseCaseProtocol {
    func execute(route: AppRoute, configuration: RouteConfiguration)
}

public final class NavigateUseCase: NavigateUseCaseProtocol {
    private let router: RouterProtocol

    public init(router: RouterProtocol) {
        self.router = router
    }

    public func execute(route: AppRoute, configuration: RouteConfiguration) {
        // 前置校验钩子（预留）：后续可在此添加登录校验、feature flag 检查等
        guard canNavigate(to: route) else { return }
        router.navigate(to: route, configuration: configuration)
    }

    /// 前置校验。当前始终返回 true，作为占位钩子。
    /// 后续可注入 PreCheckProtocol 实现登录态/权限校验。
    private func canNavigate(to route: AppRoute) -> Bool {
        true
    }
}
```

### 5. `Packages/Domain/Sources/Domain/RoutingDomain/DI/DIContainer+RoutingDomain.swift`

```swift
import Foundation
import DIAbstraction
import RoutingAbstraction

extension DIContainer {
    @MainActor
    public static func registerNavigateUseCase() {
        DIContainer.shared.register(NavigateUseCaseProtocol.self) { _ in
            let router = DIContainer.shared.resolve(RouterProtocol.self)
            return NavigateUseCase(router: router!)
        }
    }
}
```

### 6. `Packages/Abstraction/Sources/Abstraction/AnalyticsAbstraction/TrackPageLifecycleUseCaseProtocol.swift`

```swift
import Foundation

public protocol TrackPageLifecycleUseCaseProtocol {
    func start(pageIdentifier: String, duration: TimeInterval, extraParameters: [String: Any]?)
}
```

### 7. `Packages/Domain/Sources/Domain/AnalyticsDomain/Usecase/TrackPageLifecycleUseCase.swift`

```swift
import Foundation
import AnalyticsAbstraction
import DIAbstraction

final class TrackPageLifecycleUseCase: TrackPageLifecycleUseCaseProtocol {
    private let analyticsWrapper: AnalyticsWrapperProtocol

    init(analyticsWrapper: AnalyticsWrapperProtocol) {
        self.analyticsWrapper = analyticsWrapper
    }

    func start(pageIdentifier: String, duration: TimeInterval, extraParameters: [String: Any]?) {
        let paramString: String = {
            if let extra = extraParameters, !extra.isEmpty {
                let extraDesc = extra.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                return "page=\(pageIdentifier)&duration=\(duration)&\(extraDesc)"
            }
            return "page=\(pageIdentifier)&duration=\(duration)"
        }()
        analyticsWrapper.trackEvent(paramString)
    }
}
```

### 8. `Packages/Domain/Tests/RoutingDomainTests/RoutingDomainTests.swift`

```swift
import Testing
@testable import Domain

final class MockRouter: RouterProtocol {
    var navigatedRoute: AppRoute?
    var navigatedConfiguration: RouteConfiguration?
    var goBackCalled = false
    var goBackAnimated = false

    func navigate(to route: AppRoute, configuration: RouteConfiguration) {
        navigatedRoute = route
        navigatedConfiguration = configuration
    }

    func goBack(animated: Bool) {
        goBackCalled = true
        goBackAnimated = animated
    }
}

// A test-only concrete AppRoute for testing
struct TestRoute: AppRoute {
    let id: String
}

@Test("NavigateUseCase correctly forwards route and configuration to RouterProtocol")
func testNavigateUseCaseForwardsRoute() {
    let mockRouter = MockRouter()
    let useCase = NavigateUseCase(router: mockRouter)
    let route = TestRoute(id: "test")
    let config = RouteConfiguration()

    useCase.execute(route: route, configuration: config)

    #expect(mockRouter.navigatedRoute is TestRoute)
    #expect(mockRouter.navigatedConfiguration != nil)
}

@Test("NavigateUseCase uses default configuration when .default is passed")
func testNavigateUseCaseDefaultConfig() {
    let mockRouter = MockRouter()
    let useCase = NavigateUseCase(router: mockRouter)
    let route = TestRoute(id: "test_default")

    useCase.execute(route: route, configuration: .default)

    #expect(mockRouter.navigatedRoute is TestRoute)
    #expect(mockRouter.navigatedConfiguration?.presentationStyle == nil)
}
```

### 9. `Packages/Domain/Tests/AnalyticsDomainTests/AnalyticsDomainTests.swift`

```swift
import Testing
@testable import Domain

final class MockAnalyticsWrapper: AnalyticsWrapperProtocol {
    var trackedEvents: [String] = []

    func trackEvent(_ event: String) {
        trackedEvents.append(event)
    }
}

@Test("TrackPageLifecycleUseCase calls trackEvent with page identifier and duration")
func testTrackPageLifecycle() {
    let mockWrapper = MockAnalyticsWrapper()
    let useCase = TrackPageLifecycleUseCase(analyticsWrapper: mockWrapper)

    useCase.start(pageIdentifier: "product_detail", duration: 5.0, extraParameters: nil)

    #expect(mockWrapper.trackedEvents.count == 1)
    #expect(mockWrapper.trackedEvents.first?.contains("page=product_detail") == true)
    #expect(mockWrapper.trackedEvents.first?.contains("duration=5.0") == true)
}

@Test("TrackPageLifecycleUseCase includes extra parameters when provided")
func testTrackPageLifecycleWithExtraParams() {
    let mockWrapper = MockAnalyticsWrapper()
    let useCase = TrackPageLifecycleUseCase(analyticsWrapper: mockWrapper)

    useCase.start(
        pageIdentifier: "cart",
        duration: 10.0,
        extraParameters: ["item_count": 3]
    )

    #expect(mockWrapper.trackedEvents.count == 1)
    let event = mockWrapper.trackedEvents.first!
    #expect(event.contains("page=cart") == true)
    #expect(event.contains("duration=10.0") == true)
    #expect(event.contains("item_count=3") == true)
}
```

### 10. Modify `Packages/Domain/Sources/Domain/AnalyticsDomain/DI/DI.swift`

```swift
extension DIContainer {
    // ... existing registerSendProductDetailAnalyticsDataUseCase ...

    @MainActor
    public static func registerTrackPageLifecycleUseCase() {
        DIContainer.shared.register(TrackPageLifecycleUseCaseProtocol.self) { _ in
            let wrapper = DIContainer.shared.resolve(AnalyticsWrapperProtocol.self)
            return TrackPageLifecycleUseCase(analyticsWrapper: wrapper!)
        }
    }
}
```

## 执行顺序

1. `Packages/Domain/Package.swift` — 新增 `RoutingDomain` 和 `RoutingAbstraction` 依赖声明
2. `TrackPageLifecycleUseCaseProtocol.swift` — AnalyticsAbstraction 新协议
3. `TrackPageLifecycleUseCase.swift` — AnalyticsDomain 实现
4. `DI.swift` (AnalyticsDomain) — 新增 DI 注册
5. `NavigateUseCase.swift` — RoutingDomain 实现
6. `DIContainer+RoutingDomain.swift` — RoutingDomain DI 注册
7. `RoutingDomainTests.swift` — NavigateUseCase 单测
8. `AnalyticsDomainTests.swift` — TrackPageLifecycle 单测
9. 验证：`cd Packages/Domain && swift test`

## 验收清单

- [ ] NavigateUseCase 只依赖 RouterProtocol 协议，不 import UIKit
- [ ] TrackPageLifecycleUseCaseProtocol 定义在 AnalyticsAbstraction
- [ ] TrackPageLifecycleUseCase 复用 AnalyticsWrapperProtocol 发送事件
- [ ] NavigateUseCase 有单测：mock RouterProtocol，验证正确转发跳转参数
- [ ] TrackPageLifecycleUseCase 有单测：验证正确调用 AnalyticsWrapperProtocol
- [ ] `cd Packages/Domain && swift test` 全部通过

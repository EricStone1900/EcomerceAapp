# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Skills

For any SwiftUI-related task — including writing views, 
reviewing state management, fixing performance, 
animations, navigation, or analyzing .trace files — 
always use the swiftui-expert-skill.

Trigger phrases that should activate this skill:
- Any mention of SwiftUI, View, @State, @Observable
- Performance issues, hitches, hangs
- List, NavigationStack, Sheet, Animation
- Instruments or .trace analysis

## Build & Test Commands

Do not build without approval — the project uses SPM packages that resolve via Xcode.

- **Open in Xcode**: `xed .`
- **Build/run from terminal**: Use Xcode (⌘R) or `xcodebuild` for CI
- **Run all tests for one package**: `cd Packages/{PackageName} && swift test` (e.g. `cd Packages/Domain && swift test`)
- **Run a specific test**: `swift test --filter {TestTargetName}/{testMethod}` (e.g. `swift test --filter RoutingDomainTests/testNavigateUseCaseForwardsRoute`)
- **Build a single package**: `cd Packages/{PackageName} && swift build`

### Test Locations

| Package | Test Target | Has Tests? |
|---------|-------------|------------|
| Abstraction/`{Feature}Abstraction` | `{Feature}AbstractionTests` | ✓ (except Routing, WebContainer) |
| Domain/`{Feature}Domain` | `{Feature}DomainTests` | ✓ (except WebContainer) |
| Data/`{Feature}Data` | `{Feature}DataTests` | ✓ (except WebContainer) |
| Presentation/`{Feature}Feature` | `{Feature}FeatureTests` | ✓ (all features) |
| Utilities/Networking (API) | APITests | ✓ |
| Utilities/Utils | — | No tests |

Routing (RoutingDomain) has 5 unit tests — use `swift test --filter RoutingDomainTests`.
AnalyticsDomain (TrackPageLifecycleUseCase) has 7 unit tests — use `swift test --filter AnalyticsDomainTests`.
RoutingData (RouteFactoryRegistry) has 2+ unit tests — use `swift test --filter RoutingDataTests`.
WebContainer has no tests at any layer (Abstraction, Domain, Data skip them).

## Architecture Overview

Clean Architecture iOS app with 4 layers as separate SPM packages under `Packages/`.

```
Presentation/Features → Domain → Abstraction ← Data
                                ↑              ↑
                                └── Utilities ──┘
```

**Key pattern**: Outer layers depend on inner layers only through protocols defined in `Abstraction`. No inward dependencies from inner to outer layers.

### Layer Dependency Map

| Layer | What it contains | Depends on |
|-------|-----------------|------------|
| **Abstraction** | Protocols only (Repository, UseCase, DomainModel, DIContainer, Routing) | RxSwift, Swinject |
| **Domain** | Use case implementations | Abstraction, RxSwift |
| **Data** | Repository + Service implementations, DTOs, AppRouter | Abstraction, Networking, RxSwift |
| **Presentation** | SwiftUI Views + ViewModels (ObservableObject), Route enums + factories | Domain protocols, Abstraction, Utils, PresentationCore |
| **Utilities** | Networking/API, Utils (Rx→Combine bridge), Analytics, PresentationCore | RxSwift, RxCocoa |

### Package Structure Pattern

Every `Package.swift` uses a **`CaseIterable` enum-based pattern** with typed dependency helpers:

```swift
enum DomainProduct: String, CaseIterable {
    case ProductDomain
    // ...
}

// Each enum provides: .target(), .testTarget(), .product
// Dependency helpers: .internal(.ProductDomain), .external(.RxSwift), .abstraction(.BasketAbstraction), .utility(.API)
```

To add a new target to an existing package:
1. Add a new case to the `CaseIterable` enum
2. Define `dependencies` and `testsDependencies` in the computed property switch
3. If tests should be skipped (like WebContainer), return `[]` from `testsTargets`

### Data Flow Pattern

```
View → ViewModel (ObservableObject) → UseCaseProtocol → UseCase
  → RepositoryProtocol → Repository → Service → APIProvider → URLSession
```

RxSwift `Observable` flows from networking → service → repository → use case = ViewModel boundary. At that boundary, `Utils.asPublisher()` bridges to Combine `Publisher`, then `assign(to: \.published, on: self)` drives `@Published` properties.

### Key RxSwift → Combine Bridge

```swift
import Utils

getBasketUseCase.start(userID: userId)
    .asPublisher()                  // Observable<T> → AnyPublisher<T, Error>
    .receive(on: DispatchQueue.main)
    .assign(to: \.baskets, on: self)
    .store(in: &cancellables)
```

ViewModels hold `Set<AnyCancellable>` and resolve use cases from `DIContainer.shared.resolve()`.

### Dependency Injection

`DIContainer.shared` is a thin wrapper around Swinject's `Container` singleton. Each module has a `DI/` directory extending `DIContainer` with static `register*()` methods:

```swift
extension DIContainer {
    @MainActor public static func registerBasketRepository() {
        DIContainer.shared.register(BasketRepositoryProtocol.self) { _ in
            let service = DIContainer.shared.resolve(BasketService.self)!
            return BasketRepository(basketService: service!)
        }
    }
}
```

All registrations happen eagerly in `MyEcommerceApp.init()` in dependency order:
1. API Provider → 2. Services → 3. Repositories → 4. Use Cases → 5. Utilities → 6. **New Routing** → 7. App-level (legacy WebContainer)

### Routing System Architecture

The unified routing system spans multiple layers:

**Abstraction (RoutingAbstraction):**
- `AppRoute` — marker protocol for typed routes
- `RouterProtocol` — `navigate(to:configuration:)` / `goBack(animated:)`
- `RouteFactoryProtocol` — `canHandle(_:)` / `makeViewController(for:)`
- `RouteConfiguration` — aggregates presentationStyle, transition, backButton, barVisibility, titleConfiguration
- `RoutePresentationStyle` / `RouteModalStyle` — push vs present
- `RouteTransition` / `RouteSystemTransition` / `RouteAnimatorProviding` — animation config
- `RouteBackButtonConfiguration` / `RouteBarVisibilityConfiguration` / `RouteTitleConfiguration`
- `PageLifecycleTrackable` — optional analytics protocol

**Domain (RoutingDomain):**
- `NavigateUseCase` — navigation orchestration with pre-check hooks

**Data (RoutingData):**
- `RouteFactoryRegistry` — aggregates RouteFactoryProtocol instances
- `AppRouter` — implements RouterProtocol with push/present/metadata stack/transitions/bar visibility/title styling
- `TransitioningCoordinator` — bridges custom animations to UIKit delegates

**Utilities (PresentationCore):**
- `BaseHostingController` — UIHostingController subclass with auto page-dwell-time analytics
- `BaseNavigationController` — UINavigationController subclass with unified nav bar appearance

**Presentation layer** — each feature has a `Route/` directory:
- `{Feature}Route.swift` — route enum conforming to `AppRoute`
- `{Feature}RouteFactory.swift` — factory conforming to `RouteFactoryProtocol`, creates `BaseHostingController`-wrapped views

### Navigation Flow

```
LoginView → .fullScreenCover (when isConnected)
  → TabView (TabRouter via @EnvironmentObject)
    ├── Products Tab (ProductListView → push → ItemDetailView)
    ├── Basket Tab (BasketView)
    └── WebTest Tab (WebTestEntryView → push → WebContainerView)
```

`TabRouter` (ObservableObject with `@Published var screen: Screen`) controls tab selection.
The new `AppRouter` is registered and ready for programmatic navigation alongside the existing flow.

### WebContainer Bridge (JS ↔ Native) — Legacy

JS in web page sends `window.webkit.messageHandlers.nativeBridge.postMessage({action, target, params})` → WKWebView → `WebScriptMessageHandler` → JSON parsed into `WebBridgeCommand` → `ProcessBridgeCommandUseCase` matches against `WebBridgeRuleRepository` (7 pre-registered rules) → `NativeBridgeRouter.dispatch()` → `WebRouteFactoryProtocol.makeViewController(route)`.

**Coexistence**: The legacy WebContainer bridge (`WebRouteFactoryProtocol` + `NativeBridgeRouter`) and the new routing system (`RouterProtocol` + `RouteFactoryProtocol`) are independently registered and non-interfering. The legacy path remains for WebView JS → Native navigation.

### Environment Switching

| Aspect | Dev (default in DEBUG) | Production |
|--------|----------------------|------------|
| Launch arg | `-environment dev` | `-environment prd` |
| API base URL | `http://localhost:8080` | `https://api.myecoapp.com:443` |
| API provider | `MockAPIProvider` (canned data, 10 mock products) | Real `APIProvider` (URLSession) |
| Mock delay | 1s configurable | N/A |

In DEBUG, reads from `-environment` launch argument. In RELEASE, always defaults to `.prd`.

### Package Count

13 `Package.swift` files producing 20+ SPM targets across ~130 source files.

### Docs

- `docs/architecture.md` — Detailed architecture documentation
- `docs/plans/` — Implementation plans (8 stages)
- `docs/specs/` — Feature specifications (8 stages)

## Common Development Tasks

### Adding a New Feature

1. **Define protocols** in `Packages/Abstraction/Sources/Abstraction/{Feature}Abstraction/` — repository, use case, domain model protocols
2. **Register DI** — extend the enum in Abstraction's `Package.swift`
3. **Implement use cases** in `Packages/Domain/Sources/Domain/{Feature}Domain/` with a `DI/DIContainer+{Feature}Domain.swift` registration file
4. **Implement data layer** in `Packages/Data/Sources/Data/{Feature}Data/` — DTO, Service, Repository, DI
5. **Create SwiftUI feature** in `Packages/Presentation/{Feature}Feature/` — View + ViewModel (ObservableObject)
6. **Add route definition** — `Route/{Feature}Route.swift` (conform to `AppRoute`)
7. **Add route factory** — `Route/{Feature}RouteFactory.swift` (implement `RouteFactoryProtocol`, wrap in `BaseHostingController`)
8. **Wire DI** in `MyEcommerceApp.init()` — call the static `register*()` methods
9. **Register factory** — add to `DIContainer.registerAllFeatureRouteFactories()` in `AppRouteFactoryRegistrar.swift`
10. **Add tests** in each layer's `Tests/` directory — note that RoutingData tests use Swift Testing framework (`import Testing`), matching the Domain layer pattern

### Adding a New Route to an Existing Feature

1. Add a new case to the feature's route enum (e.g., `ProductRoute.profile(userId:)`)
2. Handle the new case in the feature's route factory's `makeViewController(for:)`, wrapping the view in `BaseHostingController`
3. If the new route needs custom page analytics, make the view conform to `PageLifecycleTrackable`
4. The factory is already registered in DI — no further wiring needed
5. Call the navigation from any ViewModel:
   ```swift
   let router: RouterProtocol = DIContainer.shared.resolve()
   var config = RouteConfiguration()
   config.presentationStyle = .push
   router.navigate(to: ProductRoute.profile(userId: userId), configuration: config)
   ```

### DI Registration Order (in MyEcommerceApp.init)

```swift
DIContainer.registerAPIProvider()
DIContainer.register{Feature}Service()
DIContainer.register{Feature}Repository()
DIContainer.register{Feature}UseCase()
DIContainer.registerAnalyticsWrapper()
DIContainer.registerSendProductDetailAnalyticsDataUseCase()
DIContainer.registerTrackPageLifecycleUseCase()

// New routing system
DIContainer.registerRouteFactoryRegistry()
DIContainer.registerAppRouter()
DIContainer.registerNavigateUseCase()
DIContainer.registerPresentationCore()
DIContainer.registerAllFeatureRouteFactories()

// Legacy WebContainer
DIContainer.registerWebContainerData()
DIContainer.registerLoadWebContentUseCase()
DIContainer.registerProcessBridgeCommandUseCase()
DIContainer.shared.register(WebRouteFactoryProtocol.self) { ... }
DIContainer.shared.register(NativeBridgeRouter.self) { ... }
DIContainer.shared.register(WebContainerViewModel.self) { ... }
```

### Navigation State

`TabRouter` is an `@StateObject` created in `MyEcommerceApp` and passed as `@EnvironmentObject` to all tabs. To add a new tab, add a case to `Screen` enum and a `.tag()` in the `TabView`.

### Mock API

`MockAPIProvider` in Networking/API returns canned data for 10 products with configurable delay. Use it for all dev work — no backend needed. Switch to real `APIProvider` via launch arg `-environment prd`.

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
- **Run a specific test**: `swift test --filter {TestTargetName}/{testMethod}` (e.g. `swift test --filter BasketDomainTests/testExample`)
- **Build a single package**: `cd Packages/{PackageName} && swift build`

### Test Locations

| Package | Test Target | Has Tests? |
|---------|-------------|------------|
| Abstraction/`{Feature}Abstraction` | `{Feature}AbstractionTests` | ✓ (except WebContainer) |
| Domain/`{Feature}Domain` | `{Feature}DomainTests` | ✓ (except WebContainer) |
| Data/`{Feature}Data` | `{Feature}DataTests` | ✓ (except WebContainer) |
| Presentation/`{Feature}Feature` | `{Feature}FeatureTests` | ✓ (all features) |
| Utilities/Networking (API) | APITests | ✓ |
| Utilities/Utils | — | No tests |

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
| **Abstraction** | Protocols only (Repository, UseCase, DomainModel, DIContainer) | RxSwift, Swinject |
| **Domain** | Use case implementations | Abstraction, RxSwift |
| **Data** | Repository + Service implementations, DTOs | Abstraction, Networking, RxSwift |
| **Presentation** | SwiftUI Views + ViewModels (ObservableObject) | Domain protocols, Abstraction, Utils |
| **Utilities** | Networking/API, Utils (Rx→Combine bridge), Analytics | RxSwift, RxCocoa |

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
1. API Provider → 2. Services → 3. Repositories → 4. Use Cases → 5. Utilities → 6. App-level (routers, VMs)

### Navigation Flow

```
LoginView → .fullScreenCover (when isConnected)
  → TabView (TabRouter via @EnvironmentObject)
    ├── Products Tab (ProductListView → push → ItemDetailView)
    ├── Basket Tab (BasketView)
    └── WebTest Tab (WebTestEntryView → push → WebContainerView)
```

`TabRouter` (ObservableObject with `@Published var screen: Screen`) controls tab selection.

### WebContainer Bridge (JS ↔ Native)

JS in web page sends `window.webkit.messageHandlers.nativeBridge.postMessage({action, target, params})` → WKWebView → `WebScriptMessageHandler` → JSON parsed into `WebBridgeCommand` → `ProcessBridgeCommandUseCase` matches against `WebBridgeRuleRepository` (7 pre-registered rules) → `NativeBridgeRouter.dispatch()` → `WebRouteFactoryProtocol.makeViewController(route)`.

Route resolution is deferred to the App layer (`AppWebRouteFactory`), keeping WebContainer feature package independent.

### Environment Switching

| Aspect | Dev (default in DEBUG) | Production |
|--------|----------------------|------------|
| Launch arg | `-environment dev` | `-environment prd` |
| API base URL | `http://localhost:8080` | `https://api.myecoapp.com:443` |
| API provider | `MockAPIProvider` (canned data, 10 mock products) | Real `APIProvider` (URLSession) |
| Mock delay | 1s configurable | N/A |

In DEBUG, reads from `-environment` launch argument. In RELEASE, always defaults to `.prd`.

### Package Count

10 `Package.swift` files producing 15+ SPM targets across ~70 source files.

### Docs

- `docs/architecture.md` — Detailed architecture documentation
- `docs/plans/` — Implementation plans
- `docs/specs/` — Feature specifications

## Common Development Tasks

### Adding a New Feature

1. **Define protocols** in `Packages/Abstraction/Sources/Abstraction/{Feature}Abstraction/` — repository, use case, domain model protocols
2. **Register DI** — extend the enum in Abstraction's `Package.swift`
3. **Implement use cases** in `Packages/Domain/Sources/Domain/{Feature}Domain/` with a `DI/DIContainer+{Feature}Domain.swift` registration file
4. **Implement data layer** in `Packages/Data/Sources/Data/{Feature}Data/` — DTO, Service, Repository, DI
5. **Create SwiftUI feature** in `Packages/Presentation/{Feature}Feature/` — View + ViewModel (ObservableObject)
6. **Wire DI** in `MyEcommerceApp.init()` — call the static `register*()` methods
7. **Add tests** in each layer's `Tests/` directory

### DI Registration Order (in MyEcommerceApp.init)

```swift
DIContainer.registerAPIProvider()
DIContainer.register{Feature}Service()
DIContainer.register{Feature}Repository()
DIContainer.register{Feature}UseCase()
DIContainer.registerAnalyticsWrapper()
DIContainer.register...()
// App-level singletons (routers, factories)
DIContainer.shared.register(...) { ... }
```

### Navigation State

`TabRouter` is an `@StateObject` created in `MyEcommerceApp` and passed as `@EnvironmentObject` to all tabs. To add a new tab, add a case to `Screen` enum and a `.tag()` in the `TabView`.

### Mock API

`MockAPIProvider` in Networking/API returns canned data for 10 products with configurable delay. Use it for all dev work — no backend needed. Switch to real `APIProvider` via launch arg `-environment prd`.

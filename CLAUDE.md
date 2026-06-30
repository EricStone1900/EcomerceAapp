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

##docs
docs/plans 是记录每次执行的计划相关文档


## Build & Test Commands
在没得到允许的情况下不要执行任何Build 操作

- **Open in Xcode**: `xed .` — opens the workspace (all packages resolve via SPM)
- **Build all packages**: `swift build` (run from `Packages/` subdirectories) or build from Xcode
- **Run all tests**: `swift test` (run from any `Packages/*/` directory) or Cmd+U in Xcode
- **Run a specific test**: `swift test --filter {TestTargetName}/{testMethod}` (e.g. `swift test --filter BasketDomainTests/testExample`)
- **Run tests for a single package**: `cd Packages/{PackageName} && swift test` (e.g. `cd Packages/Domain && swift test`)

## Architecture Overview

Clean Architecture iOS app with 4 layers, each as separate Swift Packages under `Packages/`.

### Layer Dependencies (outer → inner)

```
Presentation/Features → Domain → Abstraction ← Data
                                ↑                    ↑
                                └───── Utilities ─────┘
```

### Layer Details

**Abstraction** (`Packages/Abstraction/`) — Innermost layer, no dependencies on other project packages.
- Contains only **protocols**: RepositoryProtocol, UseCaseProtocol, DomainModelProtocol
- Sub-modules: `ProductAbstraction`, `BasketAbstraction`, `UserAbstraction`, `AnalyticsAbstraction`, `DIAbstraction`
- `DIAbstraction` exports the global `DIContainer` class wrapping a Swinject `Container`
- Dependencies: Swinject, RxSwift

**Domain** (`Packages/Domain/`) — Use case implementations.
- Each domain has a `DI/` file that registers use cases into `DIContainer`
- Sub-modules: `BasketDomain`, `ProductDomain`, `UserDomain`, `AnalyticsDomain`
- Dependencies: `Abstraction` (protocols only), RxSwift

**Data** (`Packages/Data/`) — Repository + network service implementations.
- Structured as: `{Feature}Data/{Feature}Repository/`, `{Feature}Data/{Feature}Service/`, `{Feature}Data/DTO/`, `{Feature}Data/DI/`
- Repositories conform to Abstraction protocols; Services use the `API` networking layer
- Dependencies: `Abstraction`, `Networking`, RxSwift

**Utilities** (`Packages/Utilities/`): Contains separate packages:
- `Networking/API` — `APIProvider`, `APIRequestProtocol`, `APIResponse`, RxSwift-based HTTP client (URLSession + RxCocoa)
- `Utils` — RxSwift → Combine bridge (`Observable.asPublisher()`)
- `Analytics` — Minimal analytics wrapper (`AnalyticsWrapper` prints events)

**Presentation** (`Packages/Presentation/`): SwiftUI feature packages.
- Each feature has `Sources/{Feature}/` with `{Feature}View.swift` + `{Feature}ViewModel.swift`
- ViewModels use `@MainActor` + `ObservableObject`, resolve dependencies via `DIContainer.shared.resolve()`
- RxSwift Observables bridged to Combine via `Utils` `asPublisher()`, then `assign(to: \.published, on: self)`
- Sub-modules: `LoginFeature`, `ProductsFeature`, `BasketFeature`

**App Entry** (`MyEcommerceApp.swift`):
- Registers all dependencies in `init()` via `DIContainer.register*()` calls
- Flows: LoginView → fullScreenCover → TabView (Products / Basket tabs)
- `TabRouter` (ObservableObject) controls tab selection via `@Published` + `@EnvironmentObject`

### Data Flow Pattern

```
View → ViewModel (ObservableObject) → UseCaseProtocol → UseCase
  → RepositoryProtocol → Repository → Service → APIProvider → URLSession
```

All reactive chains use RxSwift `Observable` internally, bridged to Combine `Publisher` at the ViewModel layer via `Utils.asPublisher()`.

### Package Registration API

All SPM Package.swift files use an enum-based approach: `CaseIterable` enums map to targets with auto-generated `.target()` / `.testTarget()` helpers and typed dependency helpers (`.internal()`, `.external()`, `.abstraction()`, `.utility()`).

### Dependency Injection

Swinject `Container` (singleton via `DIContainer.shared`). Each layer extends `DIContainer` with static `register*()` methods in a `DI/` folder. All registrations happen eagerly in `MyEcommerceApp.init()`.

### Key Dependencies

- RxSwift 6.x, RxCocoa — reactive networking and domain layer
- Swinject 2.x — DI container
- iOS 15+ deployment target

### Networking

API communicates with a local HTTP server at `localhost:8080`. Endpoints: `POST /users`, `GET /products`, `POST /basket/add`, `GET /basket/view/{userId}`.


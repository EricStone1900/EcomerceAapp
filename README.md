# EcommerceAppDemo 🛍️

[![Platform](https://img.shields.io/badge/platform-iOS%2015.0+-blue.svg)](https://developer.apple.com/ios/)
[![Language](https://img.shields.io/badge/language-Swift-orange.svg)](https://swift.org)
[![Architecture](https://img.shields.io/badge/architecture-Clean%20Architecture-brightgreen)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
![SPM](https://img.shields.io/badge/packages-SPM-red)

A production-grade iOS e-commerce application showcasing **Clean Architecture** with **Swift Package Manager** modularization. Built with SwiftUI, RxSwift, and Swinject, featuring a **WebContainer Bridge** pattern for seamless JavaScript ↔ Native communication.

---

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Key Features](#-key-features)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Layer Details](#-layer-details)
  - [Abstraction Layer](#1-abstraction-layer)
  - [Domain Layer](#2-domain-layer)
  - [Data Layer](#3-data-layer)
  - [Presentation Layer](#4-presentation-layer)
  - [Utilities Layer](#5-utilities-layer)
- [Data Flow](#-data-flow)
- [WebContainer Bridge](#-webcontainer-bridge)
- [Dependency Injection](#-dependency-injection)
- [Environment Switching](#-environment-switching)
- [Getting Started](#-getting-started)
- [Key Architecture Decisions](#-key-architecture-decisions)

---

## 🏗 Architecture Overview

```
Presentation/Features  →  Domain  →  Abstraction  ←  Data
        │                                           ↑
        │                    ┌──────────────────────┘
        └──── Utilities ─────┘
```

This project follows **Clean Architecture** with strict dependency inversion: **outer layers depend on inner layers**, never the reverse. The innermost layer (`Abstraction`) contains only protocols — zero implementation details, zero project-internal dependencies.

### Layer Dependency Rules

| Layer | Depends On |
|---|---|
| **Presentation** (SwiftUI Features) | Domain protocols, Abstraction, Utilities |
| **Domain** (Use Cases) | Abstraction protocols only, RxSwift |
| **Data** (Repositories + Services) | Abstraction protocols, Networking |
| **Abstraction** (Pure Protocols) | Swinject, RxSwift — **zero project dependencies** |
| **Utilities** (Networking / Utils / Analytics) | Independent utilities with minimal external deps |

---

## ✨ Key Features

- **Product Browsing** — Browse a list of products with detailed views
- **Shopping Basket** — Add items to basket with quantity controls, view totals
- **User Login** — Simple username-based login flow
- **WebContainer Bridge** — Embed web content and enable JS ↔ Native bidirectional communication via a rule-based routing system
- **Analytics Tracking** — Event tracking pipeline from the app through to a backend API
- **Dev/Prod Environment Switching** — Seamless switch between mock/localhost and production API via launch arguments
- **Mock API Layer** — Fully functional mock API provider with realistic product data for offline development

---

## 🛠 Tech Stack

| Technology | Purpose |
|---|---|
| **Swift 5** | Language |
| **SwiftUI** | UI Framework (iOS 15+) |
| **Swift Package Manager** | Modular dependency management |
| **RxSwift 6.x / RxCocoa** | Reactive programming (Domain, Data, Networking) |
| **Combine** | Reactive UI bindings (Presentation layer only) |
| **Swinject 2.x** | Dependency Injection container |
| **WKWebView** | Web content embedding + JS bridge |
| **URLSession** | HTTP networking (via RxSwift wrappers) |

---

## 📁 Project Structure

```
MyEcommerce/
├── MyEcommerce/                          # App entry point
│   ├── MyEcommerceApp.swift              # @main — DI registration + navigation
│   ├── Routing/
│   │   └── AppWebRouteFactory.swift      # Composition root for WebContainer routing
│   └── Assets.xcassets/                  # App icons, colors, resources
│
├── Packages/                              # ★ All business logic as SPM packages
│   ├── Abstraction/                      # Pure protocol layer
│   ├── Domain/                           # Use case implementations
│   ├── Data/                             # Repository + service implementations
│   ├── Presentation/                     # SwiftUI feature packages
│   │   ├── LoginFeature/                 # LoginView + LoginViewModel
│   │   ├── ProductsFeature/             # ProductList + ItemDetail
│   │   ├── BasketFeature/               # BasketView + BasketViewModel
│   │   └── WebContainerFeature/         # WKWebView embedding + JS bridge
│   └── Utilities/                        # Cross-cutting utilities
│       ├── Networking/API/              # HTTP client, mock provider, environment
│       ├── Utils/                       # RxSwift → Combine bridge
│       └── Analytics/                   # Event tracking wrapper
│
├── MyEcommerceTests/                     # Unit test scaffold
├── MyEcommerceUITests/                   # UI test scaffold
│
├── CLAUDE.md                             # AI coding assistant instructions
├── docs/
│   ├── architecture.md                   # Architecture documentation (Chinese)
│   └── plans/                            # Implementation plans
│
└── .claude/                              # Claude Code configuration
```

### Package Count

**8** `Package.swift` files producing **15+** SPM targets across **~70 source files**.

---

## 🔍 Layer Details

### 1. Abstraction Layer

**Innermost layer** — defines the contracts for the entire application. Contains only **protocols** with zero implementation logic.

| Sub-module | Key Protocols |
|---|---|
| `ProductAbstraction` | `ProductRepositoryProtocol`, `GetProductsUseCaseProtocol`, `ProductDomainModelProtocol` |
| `BasketAbstraction` | `BasketRepositoryProtocol`, `AddProductUseCaseProtocol`, `GetBasketUseCaseProtocol` |
| `UserAbstraction` | `UserRepositoryProtocol`, `LoginUserUseCaseProtocol` |
| `AnalyticsAbstraction` | `AnalyticsWrapperProtocol`, `SendProductDetailAnalyticsDataUsecaseProtocol` |
| `WebContainerAbstraction` | `LoadWebContentUseCaseProtocol`, `ProcessBridgeCommandUseCaseProtocol`, `WebRouteFactoryProtocol`, models for WebContent, WebBridgeCommand, NativeBridgeAction |
| `DIAbstraction` | `DIContainer` — thin wrapper around Swinject's `Container` singleton |

### 2. Domain Layer

**Business logic layer** — implements use case protocols from Abstraction by orchestrating repository calls.

| Sub-module | Use Cases |
|---|---|
| `ProductDomain` | `GetProductsUseCase` — fetches all products via repository |
| `BasketDomain` | `AddProductUseCase` — adds product to basket; `GetBasketUseCase` — fetches user's basket |
| `UserDomain` | `LoginUserUseCase` — creates/authenticates user |
| `AnalyticsDomain` | `SendProductDetailAnalyticsDataUseCase` — tracks product view events |
| `WebContainerDomain` | `LoadWebContentUseCase` — resolves WebContent to load instructions; `ProcessBridgeCommandUseCase` — matches bridge commands against rules to produce native actions |

Each domain sub-module includes a `DI/` directory that registers its use cases into `DIContainer`.

### 3. Data Layer

**Concrete implementations** of repository and service protocols. Contains DTOs, domain model mappings, and network service calls.

| Sub-module | Structure |
|---|---|
| `ProductData` | `ProductRepository` → `ProductService` → `APIProvider` (GET /products) |
| `BasketData` | `BasketRepository` → `BasketService` → `APIProvider` (POST /basket/add, GET /basket/view/{userId}) |
| `UserData` | `UserRepository` → `UserService` → `APIProvider` (POST /users) |
| `WebContainerData` | `WebContentRepositoryImpl` — resolves WebContent enum; `WebBridgeRuleRepositoryImpl` — thread-safe bridge rule store with 7 initial rules |

Each module contains: `DTO/` (Codable), `DomainModel/` (concrete models), `Service/` (network calls), `Repository/` (protocol implementations), `DI/` (registration).

### 4. Presentation Layer

**SwiftUI feature packages** — each is independently buildable with its own `Package.swift`.

| Feature | Views | ViewModel Responsibilities |
|---|---|---|
| **LoginFeature** | `LoginView` | Resolves `LoginUserUseCaseProtocol`, manages `@Published userID` and `isConnected` |
| **ProductsFeature** | `ProductListView`, `ItemDetailView` | Fetches products, manages add-to-basket + analytics on detail view |
| **BasketFeature** | `BasketView` | Fetches basket items, calculates grand total |
| **WebContainerFeature** | `WebContainerView`, `WebTestEntryView`, `WebTestNativeProbeView` | Hosts WKWebView, processes JS bridge commands, dispatches native actions |

**UI Layer:** SwiftUI with `ObservableObject` ViewModels. RxSwift `Observable` streams are bridged to Combine `Publisher` via `Utils.asPublisher()`, then `assign(to: \.published, on: self)` drives `@Published` properties.

### 5. Utilities Layer

| Package | Description |
|---|---|
| **Networking/API** | `APIProvider` (URLSession + RxSwift), `APIRequest` protocol with defaults, `APIResponse` with parsing, `MockAPIProvider` with realistic canned data (10 mock products), environment-aware `APIConstants` |
| **Utils** | `Observable.asPublisher()` — bridges RxSwift `Observable` → Combine `AnyPublisher` |
| **Analytics** | `AnalyticsWrapper` — sends events to `POST /analytics/event`, prints results to console |

---

## 🔄 Data Flow

```
User taps "Login"
  → LoginView calls loginViewModel.login(username:)
    → LoginViewModel calls LoginUserUseCaseProtocol.start(username:)
      → LoginUserUseCase (Domain) calls UserRepositoryProtocol.addUser(username:)
        → UserRepository (Data) calls UserService.addUser(user:)
          → UserService calls APIProvider.perform(APIRequest)
            → URLSession POST to /users
  ← Observable<UserDomainModel> flows back
  ← asPublisher() bridges to Combine
  ← ViewModel.assign(to: \.userID) + assign(to: \.isConnected)
  ← SwiftUI observes @Published and presents TabView
```

### Navigation Flow

```
LoginView → .fullScreenCover (when isConnected)
  → TabView
    ├── Products Tab (ProductListView)
    │   └── Push → ItemDetailView (with Add to Basket)
    ├── Basket Tab (BasketView)
    └── WebTest Tab (WebTestEntryView → WebContainer)
```

Navigation state is managed by `TabRouter` (`ObservableObject` with `@Published var screen`) via `@EnvironmentObject`.

---

## 🌉 WebContainer Bridge

A standout feature enabling **bidirectional JavaScript ↔ Native iOS communication** through a rule-based middleware system.

### How It Works

```
JS in web page: window.webkit.messageHandlers.nativeBridge.postMessage({action, target, params})
  → WKWebViewRepresentable → WebScriptMessageHandler
    → Parses JSON into WebBridgeCommand
    → WebContainerViewModel.handleBridgeCommand
      → ProcessBridgeCommandUseCase.execute(command:)
        → WebBridgeRuleRepository: matches command against registered rules
          (exact match by action+target first, then wildcard by action)
        → Returns matched NativeBridgeAction
      → NativeBridgeRouter.dispatch(action:)
        → WebRouteFactoryProtocol.makeViewController(route)
        → navigationController.pushViewController() / presentSheet() / etc.
```

### Bridge Rules (7 pre-registered)

| Action | Target | Handler |
|---|---|---|
| `navigate` | `webTestNative` | Push `WebTestNativeProbeView` |
| `navigate` | `productDetail` | Push product detail (placeholder) |
| `system` | `camera` | Native camera interface |
| `system` | `location` | Request location permission |
| `system` | `share` | System share sheet |
| `customFunction` | `showAlert` | Native `UIAlertController` |
| `customFunction` | `calculate` | Evaluate and return result |

### WebTest Tab

A built-in debugging tab that loads `webtest.html` — a full-featured HTML test page with:
- Route navigation tests (fixed and dynamic)
- System capability invocation tests
- Custom function round-trip tests
- Live log panel showing bridge callbacks

---

## 💉 Dependency Injection

The project uses **Swinject** as its DI framework with a global singleton pattern:

```
DIContainer.shared (Swinject Container wrapper)
  ├── Registered by each module's static DI methods
  └── All registrations happen eagerly in MyEcommerceApp.init()
```

Each layer contributes registrations:
- **Networking:** `registerAPIProvider()` — resolves to `MockAPIProvider` (dev) or real `APIProvider` (prod)
- **Data layer:** `registerProductService()`, `registerProductRepository()`, etc.
- **Domain layer:** `registerGetProductsUseCase()`, `registerLoginUserUseCase()`, etc.
- **Utilities:** `registerAnalyticsWrapper()`
- **App layer:** `WebRouteFactoryProtocol`, `NativeBridgeRouter`, `WebContainerViewModel`

ViewModels resolve dependencies at runtime via `DIContainer.shared.resolve()`.

---

## 🌍 Environment Switching

Supports **Dev** and **Production** environments, selected via launch argument:

| Aspect | Dev | Production |
|---|---|---|
| **Launch arg** | `-environment dev` (default in DEBUG) | `-environment prd` (default in RELEASE) |
| **API Base URL** | `http://localhost:8080` | `https://api.myecoapp.com:443` |
| **API Provider** | `MockAPIProvider` (canned JSON responses) | Real `APIProvider` (URLSession) |
| **Mock delay** | Configurable (1s default) | N/A |

In DEBUG builds, the environment is read from the `-environment` launch argument.
In RELEASE builds, it always defaults to `.prd`.

---

## 🚀 Getting Started

### Prerequisites

- Xcode 14+
- iOS 15+ deployment target

### Running the App

```bash
# Open the project in Xcode
xed .

# Build and run (⌘R)
# Uses Mock API by default in DEBUG mode — no backend required
```

### Switching to Production

Edit the scheme in Xcode and add a launch argument:

```
-environment prd
```

Or, to test against a local server:

```bash
# Start a local HTTP server on port 8080
cd path/to/backend && swift run
```

### Running Tests

```bash
# Run all tests for a specific package
cd Packages/ProductDomain && swift test

# Run a specific test method
swift test --filter ProductDomainTests/testFetchAllProducts
```

---

## 🧩 Key Architecture Decisions

### 1. RxSwift ↔ Combine Bridge

RxSwift is used throughout the Domain and Data layers for reactive networking. At the ViewModel boundary (Presentation layer), `Observable` streams are bridged to Combine `Publisher` via `Utils/Observable+Extension.swift:asPublisher()`. This allowed the project to adopt modern SwiftUI/Combine patterns without rewriting the stable reactive networking layer.

### 2. Singleton DI with Eager Registration

All dependencies are registered eagerly in `MyEcommerceApp.init()` using a wrapping singleton (`DIContainer.shared`). This provides simple, predictable resolution at the cost of memory overhead — acceptable for an e-commerce app with relatively few services.

### 3. WebContainer with Deferred Routing

The WebContainer feature has zero knowledge of other features. Route-to-ViewController resolution is deferred to the App layer via `WebRouteFactoryProtocol`, keeping the WebContainer package independent and reusable.

### 4. Enum-Based SPM Target Registration

All `Package.swift` files use a consistent enum-based `CaseIterable` pattern with typed dependency helpers (`.internal()`, `.external()`, `.abstraction()`, `.utility()`, `.domain()`), eliminating repetitive target declarations and keeping target definitions DRY.

### 5. Mock API First Development

The `MockAPIProvider` returns realistic canned data for 10 products (MacBook Pro, iPhone, AirPods, etc.) with configurable delay and error simulation. This enables full app development and UI testing without any backend dependency.

---

## 📄 License

This project is open source and available under the MIT license.

---

*Built with ❤️ using SwiftUI, RxSwift, and Clean Architecture*

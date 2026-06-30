# Dev/PRD Environment Switching with Mock Data

## Implementation Plan

Date: 2025-06-29  
Author: AI Planning Agent

---

## 1. Approach Evaluation

### Approach A: Create ServiceProtocols + MockService implementations

**Pros:** Pure abstraction, clean separation.  
**Cons:** Requires creating 3 new protocols (ProductServiceProtocol, BasketServiceProtocol, UserServiceProtocol), 3 new mock implementations, changing all Repository init signatures from concrete types to protocols, adding protocol registrations in DI. This is the most invasive change -- every Repository and DI registration file across 3 data modules needs modification. The network layer is already protocol-abstracted (APIProviderProtocol), so this duplicates effort at a different level.

### Approach B (Recommended): MockAPIProvider implementing APIProviderProtocol

**Pros:** 
- The APIProviderProtocol already exists. Services already depend on it.
- Only change: make apiProvider injectable in each Service's init instead of hardcoded.
- Single MockAPIProvider class covers all 3 services (Product, Basket, User).
- Zero changes to Repositories, DomainModels, UseCases, or ViewModels.
- Mock data generation is centralized in one file.
- DTO -> DomainModel mapping in Repositories is tested without changes.

**Cons:** 
- Requires modifying the init of 3 Service structs (minor).
- The MockAPIProvider must route requests by path/type to return correct mock data.

### Approach C: Local mock server

**Rejected by user requirements** ("no server needed for dev").

### Approach D: Compile-time conditional compilation in Services

**Pros:** No DI changes needed.  
**Cons:** Scatters `#if DEBUG` / `#if DEV` throughout every service. Does not allow runtime environment switching. Adds conditional compilation noise to production code.

---

**Decision: Approach B -- MockAPIProvider implementing APIProviderProtocol**

---

## 2. Environment Configuration

### 2.1 Environment Enum

Create a new file in the Networking package:

**New file:** `Packages/Utilities/Networking/Sources/Networking/Environment/AppEnvironment.swift`

```swift
public enum AppEnvironment: String, CaseIterable, Sendable {
    case dev
    case prd
}
```

### 2.2 Active Environment

Create a global active environment resolver. This can be read at runtime and supports override for UI testing:

**New file:** `Packages/Utilities/Networking/Sources/Networking/Environment/EnvironmentManager.swift`

```swift
import Foundation

public enum EnvironmentManager {
    
    @MainActor public static var current: AppEnvironment = {
        #if DEBUG
        // In DEBUG builds, default to dev but allow override via launch argument
        if ProcessInfo.processInfo.arguments.contains("-environment") {
            if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-environment"),
               idx + 1 < ProcessInfo.processInfo.arguments.count {
                return AppEnvironment(rawValue: ProcessInfo.processInfo.arguments[idx + 1]) ?? .dev
            }
        }
        return .dev
        #else
        return .prd
        #endif
    }()
}
```

**Design rationale:**
- In `DEBUG` builds (development in Xcode), defaults to `.dev` with optional launch-argument override (useful for UI testing).
- In `RELEASE` builds (App Store), defaults to `.prd`.
- The `@MainActor` qualifier ensures thread-safe access to the static property.

### 2.3 APIConstants Update

Modify `APIConstants` to be environment-aware:

**Modified file:** `Packages/Utilities/Networking/Sources/Networking/API/APIConstants.swift`

```swift
import Foundation

enum APIConstants {
    
    static var host: String {
        switch EnvironmentManager.current {
        case .dev: return "localhost"
        case .prd: return "api.myecoapp.com" // Replace with actual production host
        }
    }
    
    static var scheme: String {
        switch EnvironmentManager.current {
        case .dev: return "http"
        case .prd: return "https"
        }
    }
    
    static var port: Int {
        switch EnvironmentManager.current {
        case .dev: return 8080
        case .prd: return 443
        }
    }
}
```

This works because `APIRequestProtocol` default implementations already read from `APIConstants`. When `EnvironmentManager.current == .dev` and the app uses the real `APIProvider`, it will send requests to `localhost:8080`. When `.prd`, to the production API.

---

## 3. Mock Data Design

### 3.1 Mock Data Location

Create a new module within the Networking package for mock support:

**New directory:** `Packages/Utilities/Networking/Sources/Networking/Mock/`

Files inside:
- `MockAPIProvider.swift` -- The mock provider class
- `MockDataFactory.swift` -- Centralized factory generating realistic mock data

### 3.2 Data Factory

**New file:** `Packages/Utilities/Networking/Sources/Networking/Mock/MockDataFactory.swift`

```swift
import Foundation

enum MockDataFactory {
    
    // MARK: - Products
    
    static let products: [[String: Any]] = [
        [
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "name": "MacBook Pro 16-inch M3 Max",
            "description": "Apple M3 Max chip with 16-core CPU, 40-core GPU, 48GB unified memory, 1TB SSD. Space Black.",
            "price": 3499.00,
            "category": "Laptops",
            "quantity": 15
        ],
        [
            "id": "B7B62A9E-6A3D-4F1C-9B8D-2E5F1C8A7D6E",
            "name": "iPhone 16 Pro Max 256GB",
            "description": "6.9-inch Super Retina XDR display, A18 Pro chip, 5x optical zoom, Titanium design. Natural Titanium.",
            "price": 1199.00,
            "category": "Phones",
            "quantity": 42
        ],
        [
            "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "name": "AirPods Pro 2nd Generation USB-C",
            "description": "Adaptive Audio, Active Noise Cancellation, Transparency mode, Personalized Spatial Audio, MagSafe USB-C.",
            "price": 249.00,
            "category": "Audio",
            "quantity": 100
        ],
        [
            "id": "D4E5F6A7-B8C9-0123-4567-890ABCDEF123",
            "name": "iPad Air 13-inch M2",
            "description": "13-inch Liquid Retina display, M2 chip, 128GB storage, Wi-Fi 6E, Apple Pencil Pro support. Starlight.",
            "price": 799.00,
            "category": "Tablets",
            "quantity": 28
        ],
        [
            "id": "FEDCBA98-7654-3210-FEDC-BA9876543210",
            "name": "Apple Watch Ultra 2",
            "description": "49mm titanium case, Bright 3000-nit display, Precision dual-frequency GPS, Action button, 36h battery.",
            "price": 799.00,
            "category": "Wearables",
            "quantity": 20
        ],
        [
            "id": "11111111-2222-3333-4444-555555555555",
            "name": "Mac mini M4 Pro",
            "description": "M4 Pro chip with 14-core CPU, 20-core GPU, 24GB unified memory, 512GB SSD. Compact desktop powerhouse.",
            "price": 1599.00,
            "category": "Desktops",
            "quantity": 10
        ],
        [
            "id": "22222222-3333-4444-5555-666666666666",
            "name": "Apple AirTag 4-Pack",
            "description": "Find your items with precision finding. Replaceable CR2032 battery. IP67 water and dust resistant.",
            "price": 99.00,
            "category": "Accessories",
            "quantity": 200
        ],
        [
            "id": "33333333-4444-5555-6666-777777777777",
            "name": "Belkin BoostCharge Pro 3-in-1",
            "description": "15W MagSafe charger for iPhone, Apple Watch Fast Charger, AirPods. Foldable design, works with StandBy mode.",
            "price": 149.99,
            "category": "Chargers",
            "quantity": 35
        ],
        [
            "id": "44444444-5555-6666-7777-888888888888",
            "name": "AirPods Max - Midnight Blue",
            "description": "Over-ear headphones with spatial audio, active noise cancellation, transparency mode, 20h battery life.",
            "price": 549.00,
            "category": "Audio",
            "quantity": 12
        ],
        [
            "id": "55555555-6666-7777-8888-999999999999",
            "name": "Apple Pencil Pro",
            "description": "Squeeze gesture, barrel roll, haptic feedback, Find My support. Works with M2 iPad Air and M4 iPad Pro.",
            "price": 129.00,
            "category": "Accessories",
            "quantity": 60
        ]
    ]
}
```

### 3.3 Mock API Provider

**New file:** `Packages/Utilities/Networking/Sources/Networking/Mock/MockAPIProvider.swift`

```swift
import Foundation
import RxSwift

public final class MockAPIProvider: APIProviderProtocol {
    
    private let delay: DispatchTimeInterval
    
    private let shouldFail: Bool
    
    public init(delay: DispatchTimeInterval = .milliseconds(300), shouldFail: Bool = false) {
        self.delay = delay
        self.shouldFail = shouldFail
    }
    
    public func perform(_ request: APIRequestProtocol) -> Observable<APIResponse> {
        if shouldFail {
            return Observable.error(APIError.invalidServerResponse)
        }
        
        let responseData: Data
        
        switch request.path {
        case "/products":
            let json = try! JSONSerialization.data(withJSONObject: MockDataFactory.products, options: [])
            responseData = json
            
        case "/users":
            responseData = try! JSONEncoder().encode(UserDTO(id: UUID(), userName: "MockUser_\(UUID().uuidString.prefix(8))"))
            
        case let path where path.hasPrefix("/basket/add"):
            responseData = Data()
            
        case let path where path.hasPrefix("/basket/view/"):
            let mockBasketItems: [[String: Any]] = [
                [
                    "id": UUID().uuidString,
                    "productID": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                    "productName": "MacBook Pro 16-inch M3 Max",
                    "quantity": 1,
                    "price": 3499.00
                ],
                [
                    "id": UUID().uuidString,
                    "productID": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
                    "productName": "AirPods Pro 2nd Generation USB-C",
                    "quantity": 2,
                    "price": 249.00
                ]
            ]
            responseData = try! JSONSerialization.data(withJSONObject: mockBasketItems, options: [])
            
        default:
            return Observable.error(APIError.invalidURL)
        }
        
        return Observable<Int>
            .timer(delay, scheduler: MainScheduler.instance)
            .map { _ in
                APIResponse(statusCode: 200, data: responseData)
            }
    }
}
```

**Key design points:**
- Uses the existing `APIProviderProtocol` -- no new abstractions needed.
- Returns realistic JSON data matching the DTO Codable structures.
- Adds a configurable delay (default 300ms) to simulate network latency.
- Routes by `request.path` to return appropriate mock data per endpoint.
- `shouldFail` flag enables testing error states.
- For `/basket/add`, returns empty 200 to match the `Observable<Void>` mapping in BasketService.
- For `/basket/view/{userId}`, returns a deterministic basket with 2 items.

### 3.4 Networking Package Update

**Modified file:** `Packages/Utilities/Networking/Sources/Networking/API/APIConstants.swift` (change static lets to computed vars as described above)

**Modified file:** `Packages/Utilities/Networking/Package.swift` -- The Networking product enum needs a new case and the API target needs to depend on the new Mock target for testing, OR we add the Mock files under the existing API target. 

**Recommendation:** Add Mock as a separate target in the Networking package so it can be conditionally linked only by the Data layer in dev mode. But since the environment is resolved at runtime, it's simpler to add Mock sources to the existing `API` product. The `API` product already exports `APIProviderProtocol`, and `MockAPIProvider` implements it. This avoids adding a new library product.

**Modified file:** `Packages/Utilities/Networking/Package.swift`

Add to the dependencies of the API target: the API target already has only RxSwift/RxCocoa dependencies. The Mock files just need Foundation and the API module itself. Since Mock will be part of the same target, it just needs `import Foundation`.

Alternatively -- less invasive -- create a separate `NetworkingMock` product within the same package:

```swift
enum NetworkingProduct: String, CaseIterable {
    case API
    case Mock  // NEW
}
```

With dependencies: `.internal(.API)`. This lets Data modules depend on `Mock` only in dev/debug configurations.

However, this introduces package-level complexity for a small amount of code. The simplest approach is to add Mock files directly to the `API` target, since:
1. `MockAPIProvider` is lightweight (< 60 lines)
2. `MockDataFactory` is data-only
3. `EnvironmentManager` is small
4. `AppEnvironment` is small

All live under `Sources/Networking/API/` or a new subdirectory `Sources/Networking/Mock/` within the same target.

---

## 4. Service Layer Changes

### 4.1 ProductService

**Modified file:** `Packages/Data/Sources/Data/ProductData/ProductService/ProductService.swift`

```swift
public struct ProductService {
    
    private let apiProvider: APIProviderProtocol
    
    init(apiProvider: APIProviderProtocol = APIProvider()) {  // <-- injectable with production default
        self.apiProvider = apiProvider
    }
    
    func getProducts() -> Observable<[ProductDTO]> {
        apiProvider
            .perform(ProductAPI.getProducts)
            .map([ProductDTO].self)
    }
}
```

### 4.2 BasketService

**Modified file:** `Packages/Data/Sources/Data/BasketData/BasketService/BasketService.swift`

```swift
public struct BasketService {
    
    private let apiProvider: APIProviderProtocol
    
    init(apiProvider: APIProviderProtocol = APIProvider()) {  // <-- injectable with production default
        self.apiProvider = apiProvider
    }
    
    // ... rest of the struct unchanged
}
```

### 4.3 UserService

**Modified file:** `Packages/Data/Sources/Data/UserData/UserService/UserService.swift`

```swift
public struct UserService {
    
    private let apiProvider: APIProviderProtocol
    
    init(apiProvider: APIProviderProtocol = APIProvider()) {  // <-- injectable with production default
        self.apiProvider = apiProvider
    }
    
    // ... rest of the struct unchanged
}
```

**Rationale for default parameter:** The `init()` call sites in DI (`registerUserService()`, etc.) do not need changes unless we want dev-specific wiring. The default parameter preserves backward compatibility -- existing registrations continue to create production `APIProvider` instances. The dev environment wiring happens in a single place (see Section 5).

---

## 5. Dependency Injection Wiring

### 5.1 Approach: Conditional Registration

The key question is: where does the decision happen to inject `MockAPIProvider` vs `APIProvider`?

**Option 1: In each DI registration file** (modify registerBasketService, registerProductService, registerUserService)

```swift
extension DIContainer {
    @MainActor public static func registerProductService() {
        DIContainer.shared.register(ProductService.self) { _ in
            switch EnvironmentManager.current {
            case .prd:
                return ProductService(apiProvider: APIProvider())
            case .dev:
                return ProductService(apiProvider: MockAPIProvider())
            }
        }
    }
}
```

**Option 2: Register APIProviderProtocol in DI and resolve it**

Register `APIProviderProtocol` first, then services resolve it:

```swift
extension DIContainer {
    @MainActor public static func registerAPIProvider() {
        DIContainer.shared.register(APIProviderProtocol.self) { _ in
            switch EnvironmentManager.current {
            case .prd: return APIProvider()
            case .dev: return MockAPIProvider()
            }
        }
    }
}

extension DIContainer {
    @MainActor public static func registerProductService() {
        DIContainer.shared.register(ProductService.self) { _ in
            let provider = DIContainer.shared.resolve(APIProviderProtocol.self)!
            return ProductService(apiProvider: provider)
        }
    }
}
```

**Recommendation: Option 2 (register APIProviderProtocol in DI)** because:
- Single point of truth for which provider to use.
- If a new service is added, it just resolves `APIProviderProtocol` -- no duplicating the switch.
- The switch on `EnvironmentManager.current` happens once, at registration time.

Register `APIProviderProtocol` **before** any service in `MyEcommerceApp.init()`:

```swift
init() {
    DIContainer.registerAPIProvider()      // NEW -- must be first
    DIContainer.registerUserService()
    DIContainer.registerUserRepository()
    // ... rest unchanged
}
```

However, note a subtlety: Swinject registrations are closures that run lazily (on first `resolve`). If we register `APIProviderProtocol` once and resolve it inside each service's registration, the switch on `EnvironmentManager.current` runs at registration time, not resolve time. This is fine because `EnvironmentManager.current` is set once at app launch and never changes.

---

## 6. Detailed File-by-File Change Summary

### New Files to Create

| # | File Path | Purpose |
|---|-----------|---------|
| 1 | `Packages/Utilities/Networking/Sources/Networking/Environment/AppEnvironment.swift` | `AppEnvironment` enum (.dev, .prd) |
| 2 | `Packages/Utilities/Networking/Sources/Networking/Environment/EnvironmentManager.swift` | Runtime environment resolver with DEBUG default |
| 3 | `Packages/Utilities/Networking/Sources/Networking/Mock/MockDataFactory.swift` | Static mock data (products, users, basket items) |
| 4 | `Packages/Utilities/Networking/Sources/Networking/Mock/MockAPIProvider.swift` | `MockAPIProvider: APIProviderProtocol` returning mock data |
| 5 | `Packages/Utilities/Networking/Sources/Networking/DI/APIProviderDI.swift` | DI registration for `APIProviderProtocol` |
| 6 | `docs/plans/dev-prd-environment-switching-plan.md` | This document |

### Existing Files to Modify

| # | File Path | Change |
|---|-----------|--------|
| 7 | `Packages/Utilities/Networking/Sources/Networking/API/APIConstants.swift` | Convert static lets to computed vars reading from `EnvironmentManager.current` |
| 8 | `Packages/Data/Sources/Data/ProductData/ProductService/ProductService.swift` | Add `apiProvider:` parameter to `init` with default |
| 9 | `Packages/Data/Sources/Data/BasketData/BasketService/BasketService.swift` | Add `apiProvider:` parameter to `init` with default |
| 10 | `Packages/Data/Sources/Data/UserData/UserService/UserService.swift` | Add `apiProvider:` parameter to `init` with default |
| 11 | `Packages/Data/Sources/Data/ProductData/DI/DI.swift` | Resolve `APIProviderProtocol` inside `registerProductService` |
| 12 | `Packages/Data/Sources/Data/BasketData/DI/DI.swift` | Resolve `APIProviderProtocol` inside `registerBasketService` |
| 13 | `Packages/Data/Sources/Data/UserData/DI/DI.swift` | Resolve `APIProviderProtocol` inside `registerUserService` |
| 14 | `MyEcommerce/MyEcommerceApp.swift` | Add `DIContainer.registerAPIProvider()` call **before** all service registrations |

---

## 7. Mock Data Scenarios

### 7.1 Product List (GET /products)

Returns 10 realistic products (see MockDataFactory above) covering multiple categories (Laptops, Phones, Audio, Tablets, Wearables, Desktops, Accessories, Chargers). Each product has realistic pricing and descriptions.

### 7.2 User Registration (POST /users)

Returns a `UserDTO` with a random UUID and a generated username (`"MockUser_XXXXXXXX"`). This enables the login flow to work in dev mode -- the LoginViewModel gets back a real `UserDomainModelProtocol` with a valid UUID.

### 7.3 Add to Basket (POST /basket/add)

Returns an empty `200 OK` response. The production server returns some representation but BasketService maps it to `Observable<Void>` anyway, so empty data is correct.

### 7.4 View Basket (GET /basket/view/{userId})

Returns 2 items:
1. MacBook Pro 16-inch M3 Max (qty: 1, $3,499.00)
2. AirPods Pro 2nd Gen USB-C (qty: 2, $249.00)

Total: $3,997.00 -- a realistic basket.

---

## 8. Impact on Existing Architecture Layers

### Presentation Layer (ViewModels) -- No changes needed

ViewModels resolve `GetProductsUseCaseProtocol`, `LoginUserUseCaseProtocol`, etc. from DI. Neither the use cases nor their protocols change. The ViewModels are completely unaware of the environment.

### Domain Layer (UseCases) -- No changes needed

UseCases take `RepositoryProtocol` dependencies. Repositories don't change their type or protocol -- they still take concrete Service types.

### Data Layer (Repositories) -- No changes needed

Repositories continue to take `ProductService`, `BasketService`, `UserService` in init. The services still expose the same methods. The only change is that `apiProvider` inside each service is now injectable and will be a `MockAPIProvider` in dev mode.

### DTO -> DomainModel Mapping -- No changes needed

Repositories map DTOs to DomainModels. In dev mode, the DTOs come from `MockAPIProvider` which serializes JSON matching the DTO structure. The `parse<T: Decodable>` -> `map` chain works identically. This also serves as an integration test of the DTO Codable conformance.

---

## 9. Testing and Verification

### 9.1 Unit Test: MockAPIProvider

Create a unit test that:
1. Creates a `MockAPIProvider`
2. Calls `perform(ProductAPI.getProducts)` and verifies it emits one `APIResponse`
3. Parses the response as `[ProductDTO]` and verifies count == 10
4. Verifies the first product name == "MacBook Pro 16-inch M3 Max"
5. Repeats for `/users`, `/basket/add`, `/basket/view/{uuid}`

**New test file:** `Packages/Utilities/Networking/Tests/APITests/MockAPIProviderTests.swift`

### 9.2 Unit Test: EnvironmentManager

Verify that `AppEnvironment` cases match expectations:
- `AppEnvironment.dev.rawValue == "dev"`
- `AppEnvironment.prd.rawValue == "prd"`

### 9.3 Integration Test: Service with MockAPIProvider

1. Create `ProductService(apiProvider: MockAPIProvider())`
2. Call `getProducts().toBlocking().materialize()` (RxBlocking)
3. Verify the array has 10 `ProductDTO` elements
4. Repeat for `BasketService` and `UserService`

**New test files:** Add tests to each Data module's test target using RxBlocking.

### 9.4 Manual Verification: App Launch

1. Build and run in **Debug** configuration (Xcode default)
2. `EnvironmentManager.current` should be `.dev`
3. `APIConstants.host` resolves to `"localhost"` but nobody connects -- `MockAPIProvider` is used
4. Login screen: enter any username, tap login
5. The login returns immediately (300ms simulated delay) with a mock `UserDomainModel`
6. Product list loads with 10 products
7. Tapping a product, setting quantity, tapping "Add to Basket" succeeds silently
8. Basket view shows 2 items
9. To test production: change `EnvironmentManager.current` default to `.prd` and ensure network calls go to the real server

### 9.5 UI Testing with Launch Arguments

Add an XCUIApplication launch argument test:

```swift
// In UI test setup
app.launchArguments += ["-environment", "prd"]
app.launch()
```

This forces the app to use the production `APIProvider` during UI tests that hit the real server.

---

## 10. Implementation Sequence

The recommended order of implementation minimizes broken intermediate states:

1. **Step 1:** Create `AppEnvironment.swift` and `EnvironmentManager.swift` in Networking package. No existing code depends on these yet, so this is safe.
2. **Step 2:** Create `MockDataFactory.swift` and `MockAPIProvider.swift` in Networking package. No existing code depends on these yet.
3. **Step 3:** Modify `APIConstants.swift` to read from `EnvironmentManager.current`. Verify existing services still compile (they will, since default init of `APIProvider()` is unaffected).
4. **Step 4:** Modify each `Service.init` to accept injectable `apiProvider:` parameter with default. This is backward-compatible -- existing `Service()` calls still work.
5. **Step 5:** Create `APIProviderDI.swift` in Networking package. This registers `APIProviderProtocol` in DI with the environment switch.
6. **Step 6:** Modify each Data module's DI registration file (`DI.swift`) to resolve `APIProviderProtocol` and pass to the corresponding Service.
7. **Step 7:** Add `DIContainer.registerAPIProvider()` call to `MyEcommerceApp.init()` before all other registrations.
8. **Step 8:** Build, run, and verify both dev and prd scenarios.
9. **Step 9:** (Optional) Write unit and integration tests.

---

## 11. Edge Cases and Risks

### 11.1 Concurrency on EnvironmentManager.current

The `@MainActor` qualifier ensures `current` is only read from the main thread, which is where `MyEcommerceApp.init()` and all DI registration happens. If a background thread ever resolves a service, it would be a pre-existing threading issue, not introduced by this change.

### 11.2 Swinject Container Scoping

DIContainer.shared is a `Container()` (not `.container`). The `register` closures capture the environment state at registration time. Since services are registered once in `init()`, the environment selection is effectively frozen at app launch. This is by design -- runtime environment switching would be an anti-pattern anyway.

### 11.3 MockAPIProvider Serialization

The `MockAPIProvider` constructs JSON using `JSONSerialization` (for products and basket items) and `JSONEncoder` (for user). These must match the `Codable` structures in the DTOs exactly. Any changes to DTOs require updating the mock data. This is a maintenance burden but is visible at compile time -- the tests in Section 9.1 catch mismatches.

### 11.4 Portal (Debug Menu)

If the team later wants a runtime toggle (e.g., a settings screen to switch between dev/prd without rebuilding), the architecture supports it: change `EnvironmentManager.current` to be a `CurrentValueSubject` (Combine) or `BehaviorRelay` (RxSwift) and observe it in `APIConstants` live. The current plan uses compile-time selection for simplicity.

---

## 12. Diagrams

### 12.1 Architecture Flow (dev mode)

```
MyEcommerceApp.init()
  |
  v
DIContainer.registerAPIProvider()
  |-- EnvironmentManager.current == .dev
  |-- register(APIProviderProtocol.self) { _ in MockAPIProvider() }
  |
  v (resolved at runtime when a Service is first used)
ProductService.init(apiProvider: MockAPIProvider)
  |
  v
ProductService.getProducts()
  |-- calls apiProvider.perform(ProductAPI.getProducts)
  |-- MockAPIProvider matches path "/products"
  |-- serializes MockDataFactory.products as JSON
  |-- returns APIResponse(statusCode: 200, data: jsonData)
  |
  v
.map([ProductDTO].self) // Decodes JSON -> [ProductDTO]

  v
ProductRepository.fetchAll()
  |-- maps [ProductDTO] -> [ProductDomainModel]
  
  v
GetProductsUseCase.start()
  |
  v
ProductListViewModel receives [ProductDomainModelProtocol]
```

### 12.2 File Dependency Graph

```
Networking Package (API target)
  |
  |-- APIProvider.swift (unchanged)
  |-- APIProviderProtocol (unchanged)
  |-- APIConstants.swift (modified: environment-aware)
  |-- Environment/
  |     |-- AppEnvironment.swift (NEW)
  |     |-- EnvironmentManager.swift (NEW)
  |-- Mock/
  |     |-- MockAPIProvider.swift (NEW)
  |     |-- MockDataFactory.swift (NEW)
  |-- DI/
        |-- APIProviderDI.swift (NEW)

Data Package targets
  |
  |-- ProductData/UserData/BasketData
  |     |-- DI/DI.swift (modified: resolve APIProviderProtocol)
  |     |-- Services (modified: injectable init)

MyEcommerceApp
  |
  |-- MyEcommerceApp.swift (modified: registerAPIProvider())
```

---

## 13. Compilation and Build Settings

### 13.1 Xcode Build Configuration

No new build configurations needed. The existing `DEBUG` / `RELEASE` distinction is sufficient:
- `#if DEBUG` -> environment defaults to `.dev`
- `#else` (RELEASE) -> environment defaults to `.prd`

### 13.2 Package.swift Changes

**Modified file:** `Packages/Utilities/Networking/Package.swift`

No changes needed if all new files are added under the existing `API` target's path (`Sources/Networking/`). The package will auto-detect them.

If a separate `Mock` product is preferred:

```swift
enum NetworkingProduct: String, CaseIterable {
    case API
    case Mock  // NEW
}

// In dependencies for .Mock:
case .Mock:
    [
        .internal(.API)
    ]
```

Then the Data package would conditionally depend on `Mock` in dev mode via build condition, but this requires preprocessor macros in Package.swift which SPM does not currently support. Therefore, all-in-one target is the pragmatic choice.

---

## 14. Summary

The recommended approach uses the already-present `APIProviderProtocol` abstraction and creates a single `MockAPIProvider` that returns realistic e-commerce data. Changes are confined to:

- **6 new files** in the Networking package (environment enum, environment manager, mock data factory, mock API provider, DI registration)
- **4 modified files** in the Data package (3 service inits + 3 DI registrations -- the DI registration changes are in the same files as the service changes)
- **1 modified file** in the main app target (add one registration call)

Notably: 0 changes to Abstraction, Domain, or Presentation layers. The DTO -> DomainModel mapping is tested implicitly.

---

## Critical Files for Implementation

- `/Users/ericstone1900/Documents/ClaudeProject/EcommerceAppDemo/Packages/Utilities/Networking/Sources/Networking/API/APIProvider.swift` -- APIProviderProtocol definition; MockAPIProvider must implement this protocol
- `/Users/ericstone1900/Documents/ClaudeProject/EcommerceAppDemo/Packages/Utilities/Networking/Sources/Networking/API/APIConstants.swift` -- Must be modified to compute host/scheme/port based on environment
- `/Users/ericstone1900/Documents/ClaudeProject/EcommerceAppDemo/Packages/Data/Sources/Data/ProductData/ProductService/ProductService.swift` -- Representative service that needs injectable apiProvider init (same pattern for BasketService and UserService)
- `/Users/ericstone1900/Documents/ClaudeProject/EcommerceAppDemo/Packages/Data/Sources/Data/ProductData/DI/DI.swift` -- Representative DI registration that needs to resolve APIProviderProtocol (same pattern for BasketData and UserData)
- `/Users/ericstone1900/Documents/ClaudeProject/EcommerceAppDemo/MyEcommerce/MyEcommerceApp.swift` -- App entry point where registerAPIProvider() must be called before service registrations

# Analytics HTTP API Endpoint Plan

## Context

`AnalyticsWrapper.trackEvent(_:)` currently only logs to console via `print()`. We need to create a new HTTP API endpoint in the networking layer that this method calls instead, so analytics events are sent to a server.

No changes are needed to `AnalyticsWrapperProtocol`, use cases, view models, or the app entry point — all changes are confined to the infrastructure layer.

---

## Approach: Endpoint in the Analytics Package (not Data layer)

The endpoint enum (`AnalyticsAPI`) will live in the `Utilities/Analytics` package itself, **not** in the Data layer. Trade-off:

| Option | Rationale |
|--------|-----------|
| **New `AnalyticsData` target** (Data layer) | Follows `BasketAPI`/`ProductAPI` pattern, but adds disproportionate weight — full directory tree, Package.swift entry, service struct, DI boilerplate — for a single fire-and-forget POST |
| **Analytics package** (recommended) | Self-contained; keeping the endpoint definition with the code that uses it; zero Data layer changes |

The Analytics package gains a dependency on `API` (from `Networking`), which is a natural coupling: it needs to send HTTP requests.

---

## API Endpoint Design

| Property | Value |
|----------|-------|
| **Path** | `POST /analytics/event` |
| **Request body** | `{ "event": "<event_name_string>" }` |
| **Response** | `200 OK` with empty or minimal body (discarded) |
| **Content-Type** | `application/json` (set automatically by `APIProvider`) |

---

## Files to Create

### 1. `AnalyticsAPI.swift` (NEW)

**Path:** `Packages/Utilities/Analytics/Sources/Analytics/AnalyticsAPI.swift`

```swift
import Foundation
import API

enum AnalyticsAPI: APIRequestProtocol {
    case trackEvent(event: String)
}

extension AnalyticsAPI {
    var path: String { "/analytics/event" }
    var requestType: RequestType { .POST }
    var params: [String: Any] {
        switch self {
        case let .trackEvent(event):
            return ["event": event]
        }
    }
}
```

---

## Files to Modify

### 2. `AnalyticsWrapper.swift` — Inject APIProvider and make HTTP call

**Path:** `Packages/Utilities/Analytics/Sources/Analytics/AnalyticsWrapper.swift`

**Changes:**
- Import `RxSwift`, `API`
- Accept `APIProviderProtocol` in `init` (with default `APIProvider()` per existing pattern)
- Add `DisposeBag` for fire-and-forget subscription
- Replace `print` with HTTP POST; keep `print` for success/error logging

```swift
import Foundation
import RxSwift
import API
import AnalyticsAbstraction

final class AnalyticsWrapper: AnalyticsWrapperProtocol {

    private let apiProvider: APIProviderProtocol
    private let disposeBag = DisposeBag()

    init(apiProvider: APIProviderProtocol = APIProvider()) {
        self.apiProvider = apiProvider
    }

    func trackEvent(_ event: String) {
        apiProvider
            .perform(AnalyticsAPI.trackEvent(event: event))
            .subscribe(
                onNext: { _ in
                    print("Analytics event sent: \(event)")
                },
                onError: { error in
                    print("Analytics event failed: \(error.localizedDescription)")
                }
            )
            .disposed(by: disposeBag)
    }
}
```

**Key design decision:** Fire-and-forget with error logging. Analytics failures must never propagate to the caller or disrupt user flows. The `DisposeBag` is owned by the wrapper instance.

### 3. `DI.swift` — Resolve APIProviderProtocol from container

**Path:** `Packages/Utilities/Analytics/Sources/Analytics/DI.swift`

**Changes:** Add `import API`, resolve `APIProviderProtocol` from container:

```swift
import Foundation
import DIAbstraction
import AnalyticsAbstraction
import API

extension DIContainer {
    @MainActor
    public static func registerAnalyticsWrapper() {
        DIContainer.shared.register(AnalyticsWrapperProtocol.self) { _ in
            let provider = DIContainer.shared.resolve(APIProviderProtocol.self)!
            return AnalyticsWrapper(apiProvider: provider)
        }
    }
}
```

**Why this works:** `APIProviderProtocol` is already registered earlier in `MyEcommerceApp.init()` (via `DIContainer.registerAPIProvider()`) before `registerAnalyticsWrapper()` is called.

### 4. `Package.swift` (Analytics) — Add Networking/RxSwift dependency

**Path:** `Packages/Utilities/Analytics/Package.swift`

**Changes:**
- Add `../Networking` to `dependencies`
- Add `.product(name: "API", package: "Networking")` and `.product(name: "RxSwift", package: "RxSwift")` to target dependencies

### 5. `MockAPIProvider.swift` — Add analytics mock route

**Path:** `Packages/Utilities/Networking/Sources/Networking/API/Mock/MockAPIProvider.swift`

**Changes:** Add before `default:` case:

```swift
case "/analytics/event":
    responseData = Data()
```

Returns empty `Data()` with HTTP 200 — the response body is discarded by wrapper anyway.

---

## What Does NOT Change

| Layer | Files | Reason |
|-------|-------|--------|
| **Abstraction** | `AnalyticsWrapperProtocol`, `SendProductDetailAnalyticsDataUsecaseProtocol` | Protocol signatures unchanged |
| **Domain** | `SendProductDetailAnalyticsDataUseCase`, its DI | Still calls `analyticsWrapper.trackEvent()` |
| **Presentation** | `ItemDetailViewModel` | Still calls `sendProductDetailAnalyticsDataUseCase.start()` |
| **Data** | All existing targets | No new Data modules needed |
| **App entry** | `MyEcommerceApp.swift` | DI registration order already correct |

---

## Verification

1. **Build check:** `swift build --package-path Packages/Utilities/Analytics` — confirms new dependencies resolve
2. **Full Xcode build:** No import cycles or linking errors
3. **Dev run:** Trigger an analytics event → console logs `"Analytics event sent: ..."` (mock returns 200 after 300ms)
4. **Failure scenario:** Mock returns error → logs `"Analytics event failed: ..."` with no UI disruption
5. **Unit test:** Create `AnalyticsWrapper` with `MockAPIProvider`, call `trackEvent("test")`, verify no crash

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Network unavailable | Error logged, app continues normally |
| Slow response/timeout | Error caught and logged, no user impact |
| Rapid repeated calls | Each call enqueues independently; batching can be added later |
| App terminates mid-request | `DisposeBag` deallocated → RxSwift cancels subscription cleanly |
| Server returns non-200 | `APIProvider` throws `invalidServerResponse`, caught by `onError` |
| Event string with special chars | `JSONSerialization` handles Unicode/special characters correctly |

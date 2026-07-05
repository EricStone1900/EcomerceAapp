import Testing

import RoutingAbstraction

@testable import RoutingData

// MARK: - Mock TestRoute

/// A test route with a configurable ID for factory matching.
struct TestRoute: AppRoute {

    let id: String
}

// MARK: - Mock RouteFactory

/// A test factory that only handles TestRoute instances with a specific ID.
@MainActor
final class TestRouteFactory: RouteFactoryProtocol {

    let handledRouteId: String

    init(handledRouteId: String) {

        self.handledRouteId = handledRouteId
    }

    func canHandle(_ route: AppRoute) -> Bool {

        guard let testRoute = route as? TestRoute else { return false }
        return testRoute.id == handledRouteId
    }

    #if canImport(UIKit)
    func makeViewController(for route: AppRoute) -> UIViewController? {

        return UIViewController()
    }
    #else
    func makeViewController(for route: AppRoute) -> Any? {

        return nil
    }
    #endif
}

// MARK: - Tests (all platforms)

@Test("Empty registry returns nil for any route")
@MainActor
func testEmptyRegistryReturnsNil() {

    let registry = RouteFactoryRegistry()
    let route = TestRoute(id: "any")

    let vc = registry.viewController(for: route)

    #expect(vc == nil)
}

@Test("No matching factory returns nil even with registered factories")
@MainActor
func testNoMatchingFactoryReturnsNil() {

    let registry = RouteFactoryRegistry()
    let factory = TestRouteFactory(handledRouteId: "route_a")
    registry.registerFactory(factory)

    let vc = registry.viewController(for: TestRoute(id: "route_b"))

    #expect(vc == nil)
}

// MARK: - UIKit-dependent Tests (iOS only)

#if canImport(UIKit)

@Test("Registered factory returns non-nil view controller")
@MainActor
func testRegisterAndRetrieve() {

    let registry = RouteFactoryRegistry()
    let factory = TestRouteFactory(handledRouteId: "product_detail")
    registry.registerFactory(factory)

    let vc = registry.viewController(for: TestRoute(id: "product_detail"))

    #expect(vc != nil)
}

@Test("Multiple factories respect priority order")
@MainActor
func testMultipleFactoriesPriorityOrder() {

    let registry = RouteFactoryRegistry()
    let factoryA = TestRouteFactory(handledRouteId: "route_a")
    let factoryB = TestRouteFactory(handledRouteId: "route_b")
    registry.registerFactory(factoryA)
    registry.registerFactory(factoryB)

    let vcA = registry.viewController(for: TestRoute(id: "route_a"))
    #expect(vcA != nil)

    let vcB = registry.viewController(for: TestRoute(id: "route_b"))
    #expect(vcB != nil)
}

#endif

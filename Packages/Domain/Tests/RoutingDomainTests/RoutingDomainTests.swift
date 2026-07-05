import Testing

import RoutingAbstraction

@testable import RoutingDomain

// MARK: - Mock

@MainActor
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

// MARK: - Test AppRoute

struct TestRoute: AppRoute {

    let id: String
}

// MARK: - Tests

@Test("NavigateUseCase forwards route and configuration to RouterProtocol")
@MainActor
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
@MainActor
func testNavigateUseCaseDefaultConfig() {

    let mockRouter = MockRouter()
    let useCase = NavigateUseCase(router: mockRouter)
    let route = TestRoute(id: "test_default")

    useCase.execute(route: route, configuration: RouteConfiguration())

    #expect(mockRouter.navigatedRoute is TestRoute)
    #expect(mockRouter.navigatedConfiguration?.presentationStyle == nil)
    #expect(mockRouter.navigatedConfiguration?.transition == nil)
}

@Test("NavigateUseCase passes through custom presentation style")
@MainActor
func testNavigateUseCaseCustomPresentation() {

    let mockRouter = MockRouter()
    let useCase = NavigateUseCase(router: mockRouter)
    let route = TestRoute(id: "test_present")
    var config = RouteConfiguration()
    config.presentationStyle = .present(modal: .pageSheet)

    useCase.execute(route: route, configuration: config)

    #expect(mockRouter.navigatedRoute is TestRoute)

    if case .present(modal: .pageSheet) = mockRouter.navigatedConfiguration?.presentationStyle {
        #expect(Bool(true))
    } else {
        #expect(Bool(false), "Expected presentation style to be .present(modal: .pageSheet)")
    }
}

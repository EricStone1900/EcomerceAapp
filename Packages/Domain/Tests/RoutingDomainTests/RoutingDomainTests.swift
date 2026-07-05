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

@Test("NavigateUseCase passes through all configuration properties")
@MainActor
func testNavigateUseCaseAllConfigurationProperties() {

    let mockRouter = MockRouter()
    let useCase = NavigateUseCase(router: mockRouter)
    let route = TestRoute(id: "full_config")
    var config = RouteConfiguration()
    config.presentationStyle = .push
    config.transition = .system(.slideLeft)
    config.backButton = .hidden
    var barVisibility = RouteBarVisibilityConfiguration()
    barVisibility.hidesNavigationBar = true
    barVisibility.hidesTabBar = true
    barVisibility.animated = false
    config.barVisibility = barVisibility
    config.titleConfiguration = .text("Custom Title")

    useCase.execute(route: route, configuration: config)

    #expect(mockRouter.navigatedRoute is TestRoute)
    #expect(mockRouter.navigatedConfiguration?.presentationStyle != nil)
    #expect(mockRouter.navigatedConfiguration?.transition != nil)
    #expect(mockRouter.navigatedConfiguration?.backButton != nil)
    #expect(mockRouter.navigatedConfiguration?.barVisibility != nil)
    #expect(mockRouter.navigatedConfiguration?.titleConfiguration != nil)

    if case .push = mockRouter.navigatedConfiguration?.presentationStyle {
        #expect(Bool(true))
    } else {
        #expect(Bool(false), "Expected presentation style to be .push")
    }
    if case .system(.slideLeft) = mockRouter.navigatedConfiguration?.transition {
        #expect(Bool(true))
    } else {
        #expect(Bool(false), "Expected transition to be .system(.slideLeft)")
    }
}

@Test("NavigateUseCase handles multiple navigate calls sequentially")
@MainActor
func testNavigateUseCaseMultipleNavigateCalls() {

    let mockRouter = MockRouter()
    let useCase = NavigateUseCase(router: mockRouter)

    let route1 = TestRoute(id: "first")
    let config1 = RouteConfiguration()

    let route2 = TestRoute(id: "second")
    var config2 = RouteConfiguration()
    config2.presentationStyle = .present(modal: .fullScreen)

    useCase.execute(route: route1, configuration: config1)
    #expect(mockRouter.navigatedConfiguration?.presentationStyle == nil)

    useCase.execute(route: route2, configuration: config2)
    #expect(mockRouter.navigatedRoute is TestRoute)

    if let lastRoute = mockRouter.navigatedRoute as? TestRoute {
        #expect(lastRoute.id == "second")
    } else {
        #expect(Bool(false), "Expected navigatedRoute to be TestRoute with id 'second'")
    }
    #expect(mockRouter.navigatedConfiguration?.presentationStyle != nil)
    if case .present(modal: .fullScreen) = mockRouter.navigatedConfiguration?.presentationStyle {
        #expect(Bool(true))
    } else {
        #expect(Bool(false), "Expected presentation style to be .present(modal: .fullScreen)")
    }
}

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

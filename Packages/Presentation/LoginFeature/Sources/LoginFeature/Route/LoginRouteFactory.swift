import UIKit

import RoutingAbstraction
import PresentationCore

/// LoginFeature 的路由工厂。
@MainActor
public final class LoginRouteFactory: RouteFactoryProtocol {

    public init() {}

    public func canHandle(_ route: AppRoute) -> Bool {

        route is LoginRoute
    }

    public func makeViewController(for route: AppRoute) -> UIViewController? {

        guard route is LoginRoute else { return nil }

        let viewModel = LoginViewModel()
        return BaseHostingController(rootView: LoginView(loginViewModel: viewModel))
    }
}

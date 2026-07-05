import UIKit

import RoutingAbstraction
import PresentationCore

/// BasketFeature 的路由工厂。
@MainActor
public final class BasketRouteFactory: RouteFactoryProtocol {

    public init() {}

    public func canHandle(_ route: AppRoute) -> Bool {

        route is BasketRoute
    }

    public func makeViewController(for route: AppRoute) -> UIViewController? {

        guard let route = route as? BasketRoute else { return nil }

        switch route {
        case .basket(let userId):
            return BaseHostingController(rootView: BasketView(userId: userId))
        }
    }
}

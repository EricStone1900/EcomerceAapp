import UIKit

import RoutingAbstraction
import PresentationCore

/// WebContainerFeature 的路由工厂。
@MainActor
public final class WebContainerRouteFactory: RouteFactoryProtocol {

    public init() {}

    public func canHandle(_ route: AppRoute) -> Bool {

        route is WebContainerRoute
    }

    public func makeViewController(for route: AppRoute) -> UIViewController? {

        guard let route = route as? WebContainerRoute else { return nil }

        switch route {
        case .webTestEntry:
            return BaseHostingController(rootView: WebTestEntryView())

        case .webTestNativeProbe:
            return BaseHostingController(rootView: WebTestNativeProbeView())
        }
    }
}

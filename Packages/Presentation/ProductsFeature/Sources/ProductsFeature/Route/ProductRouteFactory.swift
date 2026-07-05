import UIKit

import RoutingAbstraction
import PresentationCore

/// ProductsFeature 的路由工厂。
/// 将 ProductRoute 映射为 BaseHostingController 包装的 SwiftUI View。
@MainActor
public final class ProductRouteFactory: RouteFactoryProtocol {

    public init() {}

    public func canHandle(_ route: AppRoute) -> Bool {

        route is ProductRoute
    }

    public func makeViewController(for route: AppRoute) -> UIViewController? {

        guard let route = route as? ProductRoute else { return nil }

        switch route {
        case .productList(let userId):
            return BaseHostingController(rootView: ProductListView(userId: userId))

        case .productDetail:
            // 预留：后续通过 Route 传递 productId 实现详情页路由
            return nil
        }
    }
}

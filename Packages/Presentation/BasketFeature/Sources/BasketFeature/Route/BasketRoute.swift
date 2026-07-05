import Foundation

import RoutingAbstraction

/// BasketFeature 的路由定义。
public enum BasketRoute: AppRoute, Sendable {

    /// 购物车页
    case basket(userId: UUID)
}

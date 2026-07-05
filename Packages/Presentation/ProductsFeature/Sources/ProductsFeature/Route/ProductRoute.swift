import Foundation

import RoutingAbstraction

/// ProductsFeature 的路由定义。
public enum ProductRoute: AppRoute, Sendable {

    /// 商品列表页
    case productList(userId: UUID)

    /// 商品详情页（预留）
    case productDetail(productId: UUID, userId: UUID)
}

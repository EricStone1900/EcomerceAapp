import UIKit
import SwiftUI

import DIAbstraction
import WebContainerAbstraction
import WebContainerFeature
import ProductsFeature

/// App 层的 WebContainer 路由工厂。
/// 作为 Composition Root，将路由名 + 参数解析为具体的 ViewController/View。
/// 因为只有 App 层能同时访问所有 Feature 包，所以放在这里而非 WebContainerFeature 内。
final class AppWebRouteFactory: WebRouteFactoryProtocol {

    func makeViewController(route: String, params: [String: Any]) -> UIViewController? {
        switch route {
        case "productList":
            return UIHostingController(rootView: ProductListView(userId: UUID()))
        case "webTestNativeScreen":
            return UIHostingController(rootView: WebTestNativeProbeView())
        case "productDetail":
            // 未来实现：从 params 提取 productId 跳转真实商品详情页
            return nil
        default:
            return nil
        }
    }
}

import Foundation

import DIAbstraction

import RoutingAbstraction
import RoutingData
import PresentationCore

import ProductsFeature
import BasketFeature
import LoginFeature
import WebContainerFeature

/// App 层路由工厂注册中心。
/// 在 App 启动时收集所有 Feature 的 RouteFactory 并注册进 RouteFactoryRegistry。
///
/// 因为只有 App 层能同时访问所有 Feature 包和 RoutingData 层的 RouteFactoryRegistry，
/// 所以聚合注册放在这里而非各个 Feature 内部。
extension DIContainer {

    /// 注册所有 Feature 的路由工厂。
    /// 需在 registerRouteFactoryRegistry() 之后调用。
    @MainActor
    public static func registerAllFeatureRouteFactories() {

        guard let registry = DIContainer.shared.resolve(RouteFactoryRegistry.self) else {
            print("⚠️ RouteFactoryRegistry not registered — skipping feature route registration")
            return
        }

        registry.registerFactory(ProductRouteFactory())
        registry.registerFactory(BasketRouteFactory())
        registry.registerFactory(LoginRouteFactory())
        registry.registerFactory(WebContainerRouteFactory())
    }
}

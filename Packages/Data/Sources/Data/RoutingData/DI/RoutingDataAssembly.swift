import Foundation

import DIAbstraction

import RoutingAbstraction

extension DIContainer {

    /// 注册 RouteFactoryRegistry（单例）。
    /// 各业务模块在 App 启动时通过该单例注册自己的 RouteFactoryProtocol。
    @MainActor
    public static func registerRouteFactoryRegistry() {

        DIContainer.shared.register(RouteFactoryRegistry.self) { _ in
            RouteFactoryRegistry()
        }
    }

    /// 注册 AppRouter（作为 RouterProtocol 的实现）。
    /// 需先注册 RouteFactoryRegistry。
    /// navigationController 在 resolve 后通过 setter 或属性注入完成。
    @MainActor
    public static func registerAppRouter() {

        DIContainer.shared.register(RouterProtocol.self) { resolver in
            let registry = resolver.resolve(RouteFactoryRegistry.self)!
            return AppRouter(
                navigationController: nil,
                tabBarController: nil,
                factoryRegistry: registry
            )
        }
    }
}

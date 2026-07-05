import Foundation

import RoutingAbstraction

#if canImport(UIKit)
import UIKit
#endif

/// 路由工厂注册中心。
/// 持有多个 RouteFactoryProtocol 实例，遍历匹配目标路由并产出 UIViewController。
///
/// App 启动时在此注册各业务模块的工厂，跳转时自动遍历匹配。
public final class RouteFactoryRegistry {

    private var factories: [RouteFactoryProtocol] = []

    public init() {}

    /// 注册一个路由工厂。
    /// - Parameter factory: 实现 RouteFactoryProtocol 的工厂实例
    public func registerFactory(_ factory: RouteFactoryProtocol) {

        factories.append(factory)
    }

    /// 遍历所有已注册工厂，找到第一个能处理该路由的工厂并创建 ViewController。
    /// - Parameter route: 目标路由
    /// - Returns: 目标 ViewController；无可处理工厂时返回 nil
    public func viewController(for route: AppRoute) -> UIViewController? {

        for factory in factories where factory.canHandle(route) {

            #if canImport(UIKit)
            return factory.makeViewController(for: route)
            #else
            return nil
            #endif
        }

        return nil
    }
}

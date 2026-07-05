import Foundation

import RoutingAbstraction

import DIAbstraction

/// 跳转编排 UseCase 协议。
/// 接收目标路由和配置，经前置校验后通过 RouterProtocol 执行跳转。
public protocol NavigateUseCaseProtocol {

    /// 执行跳转。
    /// - Parameters:
    ///   - route: 目标路由
    ///   - configuration: 导航配置，传 .default 或 RouteConfiguration() 表示全部走系统默认
    func execute(route: AppRoute, configuration: RouteConfiguration)
}

/// 跳转编排 UseCase。
/// 核心职责：
/// 1. 前置校验（预留钩子，如登录态检查、Feature Flag 校验）
/// 2. 调用 RouterProtocol 执行实际跳转
///
/// 使用方式：
/// ```swift
/// let useCase: NavigateUseCaseProtocol = DIContainer.shared.resolve(...)
/// useCase.execute(route: MyRoute.detail(id: "42"), configuration: .default)
/// ```
public final class NavigateUseCase: NavigateUseCaseProtocol {

    private let router: RouterProtocol

    public init(router: RouterProtocol) {

        self.router = router
    }

    public func execute(route: AppRoute, configuration: RouteConfiguration) {

        // 前置校验钩子（预留）：后续可在此添加登录校验、Feature Flag 检查等
        guard canNavigate(to: route) else { return }

        router.navigate(to: route, configuration: configuration)
    }

    /// 前置校验。当前始终返回 true，作为占位钩子。
    /// 后续可注入 PreCheckProtocol 实现登录态/权限校验。
    private func canNavigate(to route: AppRoute) -> Bool {

        true
    }
}

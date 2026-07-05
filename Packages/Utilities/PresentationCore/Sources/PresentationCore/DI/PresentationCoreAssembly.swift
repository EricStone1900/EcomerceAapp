import Foundation

import DIAbstraction

import RoutingAbstraction

/// PresentationCore DI 注册。
///
/// BaseHostingController 在 trackPageLifecycle() 中通过
/// `DIContainer.shared.resolve(TrackPageLifecycleUseCaseProtocol.self)`
/// 直接解析 UseCase，与项目现有 ViewModel Service Locator 模式一致。
///
/// 需确保 `DIContainer.registerTrackPageLifecycleUseCase()`
/// 在 App 启动时先于 PresentationCore 被调用（已在 AnalyticsDomain 的 DI 中定义）。
extension DIContainer {

    /// 注册 PresentationCore 运行时所需依赖。
    /// 调用时机：在 `registerTrackPageLifecycleUseCase()` 之后。
    @MainActor
    public static func registerPresentationCore() {

        // BaseHostingController 的 trackPageLifecycle() 通过
        // DIContainer.shared.resolve(TrackPageLifecycleUseCaseProtocol.self)
        // 即时解析 UseCase，无需预先注册。
        // 此方法作为 DI 注册顺序文档占位。
    }
}

import Foundation

/// 导航配置聚合体。
/// 将路由跳转相关的所有配置项聚合为一个结构体，
/// 作为 `RouterProtocol.navigate(to:configuration:)` 的入参。
///
/// **"All nil = system defaults" 模式：**
/// 所有属性均为 Optional，值为 nil 表示走系统/框架默认行为。
/// 通过 `RouteConfiguration()` 或 `.default` 可快速获取全 nil 实例，
/// 再按需覆写特定属性。
///
/// 使用方式：
/// ```swift
/// // 全部走默认
/// router.navigate(to: route, configuration: .default)
///
/// // 仅覆写展示样式
/// var config = RouteConfiguration()
/// config.presentationStyle = .present(modal: .pageSheet)
/// router.navigate(to: route, configuration: config)
/// ```
public struct RouteConfiguration {

    // MARK: - Properties

    /// 页面展示样式（push / present），nil 表示由 Router 自行决定
    public var presentationStyle: RoutePresentationStyle?

    /// 转场动画配置，nil 表示使用系统默认转场
    public var transition: RouteTransition?

    /// 返回按钮配置，nil 表示使用系统默认返回按钮
    public var backButton: RouteBackButtonConfiguration?

    /// 导航栏/TabBar 可见性配置，nil 表示不主动改变可见性
    public var barVisibility: RouteBarVisibilityConfiguration?

    /// 导航栏标题配置，nil 表示由目标 VC 自身管理标题
    public var titleConfiguration: RouteTitleConfiguration?

    // MARK: - Default

    /// 全部使用 nil（即系统默认值）的配置实例。
    /// 等价于 `RouteConfiguration()`。
    @MainActor public static let `default` = RouteConfiguration()

    // MARK: - Initialization

    /// 创建导航配置实例。
    ///
    /// 所有参数默认值为 nil，表示"由系统/Router 决定默认值"。
    /// 调用方只需传入需要定制的属性。
    ///
    /// - Parameters:
    ///   - presentationStyle: 页面展示样式
    ///   - transition: 转场动画
    ///   - backButton: 返回按钮配置
    ///   - barVisibility: 导航栏/TabBar 可见性
    ///   - titleConfiguration: 标题配置
    public init(
        presentationStyle: RoutePresentationStyle? = nil,
        transition: RouteTransition? = nil,
        backButton: RouteBackButtonConfiguration? = nil,
        barVisibility: RouteBarVisibilityConfiguration? = nil,
        titleConfiguration: RouteTitleConfiguration? = nil
    ) {
        self.presentationStyle = presentationStyle
        self.transition = transition
        self.backButton = backButton
        self.barVisibility = barVisibility
        self.titleConfiguration = titleConfiguration
    }
}

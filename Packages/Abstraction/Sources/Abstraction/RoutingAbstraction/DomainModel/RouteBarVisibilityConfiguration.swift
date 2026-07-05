import Foundation

/// 导航栏与底部 TabBar 可见性配置。
/// 控制目标页面的导航栏与 TabBar 显示状态。
///
/// 所有属性均为 Optional，值为 nil 表示"不主动改变当前状态"，
/// 由上层 Router 实现决定最终默认行为。
public struct RouteBarVisibilityConfiguration {

    /// 是否隐藏导航栏，nil 表示不主动改变
    public var hidesNavigationBar: Bool?

    /// 是否隐藏底部 TabBar，nil 表示不主动改变
    public var hidesTabBar: Bool?

    /// 切换时是否带动画，nil 表示由 Router 决定默认值
    public var animated: Bool?

    /// 全部使用 nil（不主动改变可见性）的默认实例。
    /// 等价于 `RouteBarVisibilityConfiguration()`。
    @MainActor public static let `default` = RouteBarVisibilityConfiguration()

    // MARK: - Initialization

    /// 创建可见性配置实例。
    /// - Parameters:
    ///   - hidesNavigationBar: 是否隐藏导航栏（nil=不改变）
    ///   - hidesTabBar: 是否隐藏 TabBar（nil=不改变）
    ///   - animated: 是否带动画（nil=Router 决定）
    public init(
        hidesNavigationBar: Bool? = nil,
        hidesTabBar: Bool? = nil,
        animated: Bool? = nil
    ) {
        self.hidesNavigationBar = hidesNavigationBar
        self.hidesTabBar = hidesTabBar
        self.animated = animated
    }
}

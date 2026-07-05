import Foundation

/// 路由标记协议。
/// 所有业务 Feature 的具体路由值（通常为枚举）需遵循此协议，
/// 作为全局导航系统的统一抽象标识。
///
/// 遵循方要求：
/// - 建议使用 `enum` 且遵循 `Hashable`，便于路由匹配与调度
/// - 命名示例：`ProductDetailRoute`、`CartRoute`、`UserProfileRoute`
public protocol AppRoute {
}

import SwiftUI

/// 圆角令牌协议。
///
/// 定义应用中使用的全部语义圆角槽位。
public protocol RadiusTokensProviding: Sendable {

    /// 小圆角（4pt）
    var small: CGFloat { get }

    /// 中等圆角（8pt）
    var medium: CGFloat { get }

    /// 大圆角（12pt）
    var large: CGFloat { get }

    /// 胶囊形（使用 Capsule 裁切，不依赖固定数值）
    var pill: CGFloat { get }
}

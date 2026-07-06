import SwiftUI

/// 阴影令牌值类型。
///
/// 包含颜色、透明度、模糊半径和偏移量，
/// 可直接映射到 SwiftUI 的 `.shadow()` 修饰器。
public struct ShadowToken: Sendable {

    /// 阴影颜色
    public let color: Color

    /// 透明度
    public let opacity: Double

    /// 模糊半径
    public let radius: CGFloat

    /// X 轴偏移
    public let offsetX: CGFloat

    /// Y 轴偏移
    public let offsetY: CGFloat

    public init(color: Color, opacity: Double, radius: CGFloat, offsetX: CGFloat = 0, offsetY: CGFloat = 0) {
        self.color = color
        self.opacity = opacity
        self.radius = radius
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

/// 阴影令牌协议。
///
/// 定义应用中使用的全部语义阴影槽位。
public protocol ShadowTokensProviding: Sendable {

    /// 卡片阴影（轻微，视觉层次较低）
    var card: ShadowToken { get }

    /// 抬升阴影（明显，视觉层次较高，如按钮/弹窗）
    var elevated: ShadowToken { get }
}

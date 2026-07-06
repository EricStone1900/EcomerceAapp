import SwiftUI

// MARK: - View Extension

/// 语义化阴影修饰器。
///
/// 使用方式：
///   `.designShadow(.elevated)` — 抬升阴影（按钮、弹窗）
///   `.designShadow(.card)` — 卡片阴影
public extension View {

    func designShadow(_ slot: DesignShadowSlot) -> some View {
        modifier(DesignShadowModifier(slot: slot))
    }
}

// MARK: - Public Enum

/// 语义化阴影类型，与 ShadowTokensProviding 的槽位对应。
public enum DesignShadowSlot: CaseIterable, Sendable {

    case card
    case elevated
}

// MARK: - Modifier

private struct DesignShadowModifier: ViewModifier {

    let slot: DesignShadowSlot

    @Environment(\.shadowTheme) private var shadowTheme

    func body(content: Content) -> some View {
        let token = shadowToken(from: shadowTheme)
        content.shadow(
            color: token.color.opacity(token.opacity),
            radius: token.radius,
            x: token.offsetX,
            y: token.offsetY
        )
    }

    private func shadowToken(from theme: ShadowTokensProviding) -> ShadowToken {
        switch slot {
        case .card:     return theme.card
        case .elevated: return theme.elevated
        }
    }
}

import SwiftUI

// MARK: - View Extension

/// 语义化圆角修饰器。
///
/// 使用方式：`.designCornerRadius(.medium)`
/// `pill` 使用 Capsule 裁切，其余使用 RoundedRectangle。
public extension View {

    func designCornerRadius(_ radius: DesignCornerRadius) -> some View {
        modifier(DesignCornerRadiusModifier(radius: radius))
    }
}

// MARK: - Public Enum

/// 语义化圆角类型，与 RadiusTokensProviding 的槽位对应。
public enum DesignCornerRadius: CaseIterable, Sendable {

    case small, medium, large, pill
}

// MARK: - Modifier

private struct DesignCornerRadiusModifier: ViewModifier {

    let radius: DesignCornerRadius

    @Environment(\.radiusTheme) private var radiusTheme

    func body(content: Content) -> some View {
        if radius == .pill {
            content.clipShape(Capsule())
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: cornerRadius(from: radiusTheme)))
        }
    }

    private func cornerRadius(from theme: RadiusTokensProviding) -> CGFloat {
        switch radius {
        case .small:  return theme.small
        case .medium: return theme.medium
        case .large:  return theme.large
        case .pill:   return 0 // 不会执行到这里
        }
    }
}

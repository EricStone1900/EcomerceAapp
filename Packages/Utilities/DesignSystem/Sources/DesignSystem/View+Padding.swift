import SwiftUI

// MARK: - View Extension

/// 语义化间距便捷访问。
///
/// 使用方式：
///   `.designPadding(.l)` — 所有边距
///   `.designPadding(.horizontal, .m)` — 指定边缘
///   `VStack(spacing: .spacingM)` — Stack 间距（使用 CGFloat 扩展）
public extension View {

    func designPadding(_ spacing: DesignSpacing) -> some View {
        padding(spacing.value(from: DefaultDesignTheme()))
    }

    func designPadding(_ edges: Edge.Set, _ spacing: DesignSpacing) -> some View {
        padding(edges, spacing.value(from: DefaultDesignTheme()))
    }
}

// MARK: - Public Enum

/// 语义化间距类型，与 SpacingTokensProviding 的槽位对应。
public enum DesignSpacing: CaseIterable, Sendable {

    case xs, s, m, l, xl, xxl

    public func value(from theme: SpacingTokensProviding) -> CGFloat {
        switch self {
        case .xs:  return theme.xs
        case .s:   return theme.s
        case .m:   return theme.m
        case .l:   return theme.l
        case .xl:  return theme.xl
        case .xxl: return theme.xxl
        }
    }
}

// MARK: - CGFloat Convenience

public extension CGFloat {

    /// 极窄间距（4pt）
    static let spacingXs: CGFloat = DefaultDesignTheme().xs

    /// 窄间距（8pt）
    static let spacingS: CGFloat = DefaultDesignTheme().s

    /// 中间距（12pt）
    static let spacingM: CGFloat = DefaultDesignTheme().m

    /// 宽间距（16pt）
    static let spacingL: CGFloat = DefaultDesignTheme().l

    /// 加宽间距（24pt）
    static let spacingXl: CGFloat = DefaultDesignTheme().xl

    /// 极大间距（32pt）
    static let spacingXxl: CGFloat = DefaultDesignTheme().xxl
}

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 默认主题实现。
///
/// 从 Asset Catalog 的 Color Set 中读取色值，
/// 深色/浅色模式由 Asset Catalog 自动适配。
/// 字体使用系统字体，并支持 Dynamic Type 缩放。
public struct DefaultDesignTheme: ColorTokensProviding {

    public init() {}

    public var primary: Color {
        Color("primary", bundle: .module)
    }

    public var secondary: Color {
        Color("secondary", bundle: .module)
    }

    public var background: Color {
        Color("background", bundle: .module)
    }

    public var textPrimary: Color {
        Color("textPrimary", bundle: .module)
    }

    public var textSecondary: Color {
        Color("textSecondary", bundle: .module)
    }

    public var success: Color {
        Color("success", bundle: .module)
    }

    public var warning: Color {
        Color("warning", bundle: .module)
    }

    public var error: Color {
        Color("error", bundle: .module)
    }
}

// MARK: - TypographyTokensProviding

extension DefaultDesignTheme: TypographyTokensProviding {

    public var largeTitle: Font {
        scaledFont(size: 34, weight: .bold, relativeTo: .largeTitle)
    }

    public var title: Font {
        scaledFont(size: 28, weight: .regular, relativeTo: .title)
    }

    public var title2: Font {
        scaledFont(size: 22, weight: .regular, relativeTo: .title2)
    }

    public var headline: Font {
        scaledFont(size: 17, weight: .semibold, relativeTo: .headline)
    }

    public var subheadline: Font {
        scaledFont(size: 15, weight: .regular, relativeTo: .subheadline)
    }

    public var body: Font {
        scaledFont(size: 17, weight: .regular, relativeTo: .body)
    }

    public var callout: Font {
        scaledFont(size: 16, weight: .regular, relativeTo: .callout)
    }

    public var caption: Font {
        scaledFont(size: 12, weight: .regular, relativeTo: .caption)
    }

    // MARK: - Dynamic Type Helper

    /// 创建支持 Dynamic Type 的系统字体。
    /// 在 iOS 上通过 UIFontMetrics 实现无障碍缩放，
    /// 在其他平台上回退到固定大小。
    private func scaledFont(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) -> Font {
        #if canImport(UIKit)
        let uiFont = UIFont.systemFont(ofSize: size, weight: weight.uiKit)
        let scaledFont = UIFontMetrics(forTextStyle: textStyle.uiKit).scaledFont(for: uiFont)
        return Font(scaledFont as CTFont)
        #else
        return Font.system(size: size, weight: weight, design: .default)
        #endif
    }
}

// MARK: - RadiusTokensProviding

extension DefaultDesignTheme: RadiusTokensProviding {

    public var small: CGFloat { 4 }
    public var medium: CGFloat { 8 }
    public var large: CGFloat { 12 }
    public var pill: CGFloat { .greatestFiniteMagnitude }
}

// MARK: - SpacingTokensProviding

extension DefaultDesignTheme: SpacingTokensProviding {

    public var xs: CGFloat { 4 }
    public var s: CGFloat { 8 }
    public var m: CGFloat { 12 }
    public var l: CGFloat { 16 }
    public var xl: CGFloat { 24 }
    public var xxl: CGFloat { 32 }
}

// MARK: - UIKit Bridge

#if canImport(UIKit)
private extension Font.Weight {

    var uiKit: UIFont.Weight {
        switch self {
        case .regular: return .regular
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .light: return .light
        case .medium: return .medium
        case .thin: return .thin
        case .ultraLight: return .ultraLight
        case .black: return .black
        default: return .regular
        }
    }
}

private extension Font.TextStyle {

    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .caption: return .caption1
        case .caption2: return .caption2
        case .footnote: return .footnote
        default: return .body
        }
    }
}
#endif

// MARK: - ShadowTokensProviding

extension DefaultDesignTheme: ShadowTokensProviding {

    public var card: ShadowToken {
        ShadowToken(
            color: .black,
            opacity: 0.1,
            radius: 4,
            offsetX: 0,
            offsetY: 2
        )
    }

    public var elevated: ShadowToken {
        ShadowToken(
            color: .black,
            opacity: 0.2,
            radius: 8,
            offsetX: 0,
            offsetY: 4
        )
    }
}

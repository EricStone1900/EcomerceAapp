import SwiftUI

/// 便捷访问 DesignSystem 颜色的 Color 扩展。
///
/// 使用方式：`Color.appPrimary`
public extension Color {

    static var appPrimary: Color {
        DefaultDesignTheme().primary
    }

    static var appSecondary: Color {
        DefaultDesignTheme().secondary
    }

    static var appBackground: Color {
        DefaultDesignTheme().background
    }

    static var appTextPrimary: Color {
        DefaultDesignTheme().textPrimary
    }

    static var appTextSecondary: Color {
        DefaultDesignTheme().textSecondary
    }

    static var appSuccess: Color {
        DefaultDesignTheme().success
    }

    static var appWarning: Color {
        DefaultDesignTheme().warning
    }

    static var appError: Color {
        DefaultDesignTheme().error
    }
}

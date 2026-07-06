import SwiftUI

// MARK: - EnvironmentKey

private struct TypographyThemeEnvironmentKey: EnvironmentKey {

    static let defaultValue: TypographyTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 字体主题。
    ///
    /// 使用方式：
    /// ```swift
    /// @Environment(\.typographyTheme) var typographyTheme
    /// ```
    var typographyTheme: TypographyTokensProviding {
        get { self[TypographyThemeEnvironmentKey.self] }
        set { self[TypographyThemeEnvironmentKey.self] = newValue }
    }
}

import SwiftUI

// MARK: - EnvironmentKey

private struct DesignThemeEnvironmentKey: EnvironmentKey {

    static let defaultValue: ColorTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 主题。
    ///
    /// 使用方式：
    /// ```swift
    /// @Environment(\.designTheme) var designTheme
    /// ```
    var designTheme: ColorTokensProviding {
        get { self[DesignThemeEnvironmentKey.self] }
        set { self[DesignThemeEnvironmentKey.self] = newValue }
    }
}

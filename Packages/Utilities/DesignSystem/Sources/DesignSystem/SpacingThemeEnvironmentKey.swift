import SwiftUI

// MARK: - EnvironmentKey

private struct SpacingThemeEnvironmentKey: EnvironmentKey {

    static let defaultValue: SpacingTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 间距主题。
    var spacingTheme: SpacingTokensProviding {
        get { self[SpacingThemeEnvironmentKey.self] }
        set { self[SpacingThemeEnvironmentKey.self] = newValue }
    }
}

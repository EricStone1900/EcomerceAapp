import SwiftUI

// MARK: - EnvironmentKey

private struct ShadowThemeEnvironmentKey: EnvironmentKey {

    static let defaultValue: ShadowTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 阴影主题。
    var shadowTheme: ShadowTokensProviding {
        get { self[ShadowThemeEnvironmentKey.self] }
        set { self[ShadowThemeEnvironmentKey.self] = newValue }
    }
}

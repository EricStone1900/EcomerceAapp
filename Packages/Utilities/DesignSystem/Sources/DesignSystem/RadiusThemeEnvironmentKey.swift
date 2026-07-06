import SwiftUI

// MARK: - EnvironmentKey

private struct RadiusThemeEnvironmentKey: EnvironmentKey {

    static let defaultValue: RadiusTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 圆角主题。
    var radiusTheme: RadiusTokensProviding {
        get { self[RadiusThemeEnvironmentKey.self] }
        set { self[RadiusThemeEnvironmentKey.self] = newValue }
    }
}

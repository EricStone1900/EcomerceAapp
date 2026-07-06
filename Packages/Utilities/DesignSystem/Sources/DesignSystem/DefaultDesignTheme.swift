import SwiftUI

/// 默认主题实现。
///
/// 从 Asset Catalog 的 Color Set 中读取色值，
/// 深色/浅色模式由 Asset Catalog 自动适配。
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

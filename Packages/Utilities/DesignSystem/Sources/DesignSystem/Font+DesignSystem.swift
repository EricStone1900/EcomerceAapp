import SwiftUI

/// 便捷访问 DesignSystem 字体的 Font 扩展。
///
/// 使用方式：`.font(.appTitle)` 或 `.font(.appHeadline)`
public extension Font {

    static var appLargeTitle: Font { DefaultDesignTheme().largeTitle }
    static var appTitle: Font { DefaultDesignTheme().title }
    static var appTitle2: Font { DefaultDesignTheme().title2 }
    static var appHeadline: Font { DefaultDesignTheme().headline }
    static var appSubheadline: Font { DefaultDesignTheme().subheadline }
    static var appBody: Font { DefaultDesignTheme().body }
    static var appCallout: Font { DefaultDesignTheme().callout }
    static var appCaption: Font { DefaultDesignTheme().caption }
}

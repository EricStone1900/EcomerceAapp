#if canImport(UIKit)
import UIKit

/// 便捷访问 DesignSystem 字体的 UIFont 扩展。
///
/// 使用方式：`UIFont.appHeadline`、`UIFont.appLargeTitle`
/// 支持 Dynamic Type，通过 UIFontMetrics 实现无障碍缩放。
public extension UIFont {

    static var appLargeTitle: UIFont {
        scaledSystemFont(size: 34, weight: .bold, textStyle: .largeTitle)
    }

    static var appTitle: UIFont {
        scaledSystemFont(size: 28, weight: .regular, textStyle: .title1)
    }

    static var appTitle2: UIFont {
        scaledSystemFont(size: 22, weight: .regular, textStyle: .title2)
    }

    static var appHeadline: UIFont {
        scaledSystemFont(size: 17, weight: .semibold, textStyle: .headline)
    }

    static var appSubheadline: UIFont {
        scaledSystemFont(size: 15, weight: .regular, textStyle: .subheadline)
    }

    static var appBody: UIFont {
        scaledSystemFont(size: 17, weight: .regular, textStyle: .body)
    }

    static var appCallout: UIFont {
        scaledSystemFont(size: 16, weight: .regular, textStyle: .callout)
    }

    static var appCaption: UIFont {
        scaledSystemFont(size: 12, weight: .regular, textStyle: .caption1)
    }

    // MARK: - Helper

    private static func scaledSystemFont(size: CGFloat, weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }
}
#endif

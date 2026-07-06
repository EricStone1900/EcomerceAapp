#if canImport(UIKit)
import UIKit

/// 便捷访问 DesignSystem 颜色的 UIColor 扩展。
///
/// 使用方式：`UIColor.appPrimary`
/// 与 SwiftUI 的 `Color.appPrimary` 读取同一份 Asset Catalog Color Set，
/// 深色/浅色模式由 Asset Catalog 自动适配。
public extension UIColor {

    static var appPrimary: UIColor {
        UIColor(named: "primary", in: .module, compatibleWith: nil)!
    }

    static var appSecondary: UIColor {
        UIColor(named: "secondary", in: .module, compatibleWith: nil)!
    }

    static var appBackground: UIColor {
        UIColor(named: "background", in: .module, compatibleWith: nil)!
    }

    static var appTextPrimary: UIColor {
        UIColor(named: "textPrimary", in: .module, compatibleWith: nil)!
    }

    static var appTextSecondary: UIColor {
        UIColor(named: "textSecondary", in: .module, compatibleWith: nil)!
    }

    static var appSuccess: UIColor {
        UIColor(named: "success", in: .module, compatibleWith: nil)!
    }

    static var appWarning: UIColor {
        UIColor(named: "warning", in: .module, compatibleWith: nil)!
    }

    static var appError: UIColor {
        UIColor(named: "error", in: .module, compatibleWith: nil)!
    }
}
#endif

import SwiftUI

/// 颜色令牌协议。
///
/// 定义应用中使用的全部语义颜色槽位。
/// 实现此协议可提供不同的主题色板（例如 DefaultDesignTheme）。
public protocol ColorTokensProviding: Sendable {

    /// 主色调（品牌色）
    var primary: Color { get }

    /// 次要色
    var secondary: Color { get }

    /// 背景色
    var background: Color { get }

    /// 主要文字色
    var textPrimary: Color { get }

    /// 次要文字色
    var textSecondary: Color { get }

    /// 成功/正向语义色
    var success: Color { get }

    /// 警告语义色
    var warning: Color { get }

    /// 错误/负向语义色
    var error: Color { get }
}

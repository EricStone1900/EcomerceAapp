import Foundation

/// 间距令牌协议。
///
/// 定义应用中使用的全部语义间距槽位，采用 4pt 网格。
public protocol SpacingTokensProviding: Sendable {

    /// 极窄间距（4pt）
    var xs: CGFloat { get }

    /// 窄间距（8pt）
    var s: CGFloat { get }

    /// 中间距（12pt）
    var m: CGFloat { get }

    /// 宽间距（16pt）
    var l: CGFloat { get }

    /// 加宽间距（24pt）
    var xl: CGFloat { get }

    /// 极大间距（32pt）
    var xxl: CGFloat { get }
}

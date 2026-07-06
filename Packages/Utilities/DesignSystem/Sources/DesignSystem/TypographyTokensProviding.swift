import SwiftUI

/// 字体字号令牌协议。
///
/// 定义应用中使用的全部语义字号槽位。
/// 支持 Dynamic Type：使用 relativeTo 让字体随系统字体大小设置自动缩放。
public protocol TypographyTokensProviding: Sendable {

    /// 大标题（34pt Bold）
    var largeTitle: Font { get }

    /// 标题（28pt Regular）
    var title: Font { get }

    /// 二级标题（22pt Regular）
    var title2: Font { get }

    /// 强调文字（17pt Semibold）
    var headline: Font { get }

    /// 辅助文字（15pt Regular）
    var subheadline: Font { get }

    /// 正文（17pt Regular）
    var body: Font { get }

    /// 标注文字（16pt Regular）
    var callout: Font { get }

    /// 说明文字（12pt Regular）
    var caption: Font { get }
}

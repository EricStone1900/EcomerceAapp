import SwiftUI

/// 统一图片加载配置模型
/// 定义默认占位图、失败图、圆角、裁剪模式等。
/// 业务方可通过修改这些静态属性来全局调整图片展示样式。
///
/// 注意：这些静态属性是全局可变状态，应在 App 启动时（MainActor 上）配置，
/// 随后尽量避免在运行时修改。
public struct ImageLoadingConfiguration {

    // MARK: - 默认占位图

    /// 加载中显示的占位图（SF Symbol）
    public nonisolated(unsafe) static var defaultPlaceholderImage: Image? = Image(systemName: "photo")

    /// 加载失败时显示的占位图
    public nonisolated(unsafe) static var defaultFailureImage: Image? = Image(systemName: "photo.badge.exclamationmark")

    // MARK: - 默认样式

    /// 默认圆角大小
    public nonisolated(unsafe) static var defaultCornerRadius: CGFloat = 8

    /// 默认裁剪模式
    public nonisolated(unsafe) static var defaultContentMode: ContentMode = .fill

    // MARK: - 默认下采样尺寸

    /// 下采样目标尺寸（用于列表缩略图）
    /// 设置为 .zero 表示不下采样
    public nonisolated(unsafe) static var defaultDownsamplingSize: CGSize = CGSize(width: 300, height: 300)

    // MARK: - Init

    private init() {}
}

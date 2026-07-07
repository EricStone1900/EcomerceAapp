import SwiftUI

import Kingfisher

/// 统一远程图片加载组件（门面）
///
/// 内部使用 Kingfisher 的 `KFImage` 实现，
/// 对外提供纯 SwiftUI 接口，隐藏第三方库细节。
///
/// 用法：
/// ```swift
/// AppRemoteImage(url: product.imageURL)
///     .frame(width: 60, height: 60)
///     .cornerRadius(8)
/// ```
public struct AppRemoteImage: View {

    // MARK: - Stored Properties

    private let url: String?
    private var placeholderView: AnyView?
    private var radius: CGFloat
    private var mode: SwiftUI.ContentMode
    private var downsampleSize: CGSize

    // MARK: - Init

    /// 创建图片加载视图
    /// - Parameter url: 图片 URL 字符串，为 nil 或空时显示占位图
    public init(url: String?) {
        self.url = url
        self.radius = ImageLoadingConfiguration.defaultCornerRadius
        self.mode = ImageLoadingConfiguration.defaultContentMode
        self.downsampleSize = ImageLoadingConfiguration.defaultDownsamplingSize
        self.placeholderView = nil
    }

    // MARK: - Chainable Modifiers

    /// 自定义加载中 / 失败时占位视图
    public func placeholder<Placeholder: View>(@ViewBuilder _ placeholder: () -> Placeholder) -> AppRemoteImage {
        var copy = self
        copy.placeholderView = AnyView(placeholder())
        return copy
    }

    /// 设置圆角大小
    public func cornerRadius(_ radius: CGFloat) -> AppRemoteImage {
        var copy = self
        copy.radius = radius
        return copy
    }

    /// 设置裁剪模式
    public func contentMode(_ mode: SwiftUI.ContentMode) -> AppRemoteImage {
        var copy = self
        copy.mode = mode
        return copy
    }

    /// 设置下采样尺寸（设为 `.zero` 可关闭下采样）
    public func downsampling(size: CGSize) -> AppRemoteImage {
        var copy = self
        copy.downsampleSize = size
        return copy
    }

    // MARK: - Body

    public var body: some View {
        if let urlString = url, let imageURL = URL(string: urlString), !urlString.isEmpty {
            kfImageView(url: imageURL)
        } else {
            defaultPlaceholder
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func kfImageView(url imageURL: URL) -> some View {
        let processor: ImageProcessor = {
            if downsampleSize != .zero, downsampleSize.width > 0, downsampleSize.height > 0 {
                return DownsamplingImageProcessor(size: downsampleSize)
            }
            return DefaultImageProcessor.default
        }()

        let image = KFImage(imageURL)
            .placeholder { _ in
                defaultPlaceholder
            }
            .setProcessor(processor)
            .resizable()
            .aspectRatio(contentMode: mode)

        if radius > 0 {
            image
                .clipShape(RoundedRectangle(cornerRadius: radius))
        } else {
            image
        }
    }

    /// 默认占位内容：优先使用链式传入的 placeholder，否则使用配置中的默认占位图
    @ViewBuilder
    private var defaultPlaceholder: some View {
        if let placeholderView {
            placeholderView
        } else if let defaultImage = ImageLoadingConfiguration.defaultPlaceholderImage {
            defaultImage
                .resizable()
                .aspectRatio(contentMode: mode)
                .foregroundColor(.secondary)
        }
    }
}

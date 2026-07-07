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

    public init(url: String?) {
        self.url = url
        self.radius = ImageLoadingConfiguration.defaultCornerRadius
        self.mode = ImageLoadingConfiguration.defaultContentMode
        self.downsampleSize = ImageLoadingConfiguration.defaultDownsamplingSize
        self.placeholderView = nil
        print("[AppRemoteImage] init: \(url ?? "nil")")
    }

    // MARK: - Chainable Modifiers

    public func placeholder<Placeholder: View>(@ViewBuilder _ placeholder: () -> Placeholder) -> AppRemoteImage {
        var copy = self
        copy.placeholderView = AnyView(placeholder())
        return copy
    }

    public func cornerRadius(_ radius: CGFloat) -> AppRemoteImage {
        var copy = self
        copy.radius = radius
        return copy
    }

    public func contentMode(_ mode: SwiftUI.ContentMode) -> AppRemoteImage {
        var copy = self
        copy.mode = mode
        return copy
    }

    public func downsampling(size: CGSize) -> AppRemoteImage {
        var copy = self
        copy.downsampleSize = size
        return copy
    }

    // MARK: - Body

    public var body: some View {
        if let urlString = url, let imageURL = URL(string: urlString), !urlString.isEmpty {
            KFImage.url(imageURL)
                .placeholder { _ in
                    placeholderContent
                }
                .onSuccess { result in
                    print("[AppRemoteImage] ✅ loaded: \(result.image.size)")
                }
                .onFailure { error in
                    print("[AppRemoteImage] ❌ fail: \(error.localizedDescription)")
                }
                .setProcessor(resolvedProcessor)
                .startLoadingBeforeViewAppear()
                .resizable()
                .aspectRatio(contentMode: mode)
                .clipShape(RoundedRectangle(cornerRadius: radius > 0 ? radius : 0))
        } else {
            placeholderContent
        }
    }

    // MARK: - Private

    private var resolvedProcessor: any ImageProcessor {
        if downsampleSize != .zero, downsampleSize.width > 0, downsampleSize.height > 0 {
            return DownsamplingImageProcessor(size: downsampleSize)
        }
        return DefaultImageProcessor.default
    }

    @ViewBuilder
    private var placeholderContent: some View {
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

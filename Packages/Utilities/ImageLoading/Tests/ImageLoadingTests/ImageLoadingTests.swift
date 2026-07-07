import Testing
import SwiftUI

@testable import ImageLoading

struct ImageLoadingTests {

    // MARK: - ImageLoadingConfiguration

    @Test func configurationDefaultValuesExist() {
        let cornerRadius = ImageLoadingConfiguration.defaultCornerRadius
        let contentMode = ImageLoadingConfiguration.defaultContentMode
        let downsampleSize = ImageLoadingConfiguration.defaultDownsamplingSize

        #expect(cornerRadius == 8)
        #expect(contentMode == .fill)
        #expect(downsampleSize == CGSize(width: 300, height: 300))
    }

    // MARK: - AppRemoteImage

    @MainActor @Test func appRemoteImageWithNilURL() {
        // 验证 nil URL 不崩溃
        let view = AppRemoteImage(url: nil)
        // 成功创建即为通过（编译期可发现类型错误）
        #expect(type(of: view) == AppRemoteImage.self)
    }

    @MainActor @Test func appRemoteImageWithEmptyURL() {
        let view = AppRemoteImage(url: "")
        #expect(type(of: view) == AppRemoteImage.self)
    }

    @MainActor @Test func appRemoteImageWithInvalidURL() {
        let view = AppRemoteImage(url: "not-a-valid-url")
        #expect(type(of: view) == AppRemoteImage.self)
    }

    @MainActor @Test func appRemoteImageWithValidURL() {
        let view = AppRemoteImage(url: "https://picsum.photos/id/1/300/300")
        #expect(type(of: view) == AppRemoteImage.self)
    }

    @MainActor @Test func appRemoteImageWithCustomPlaceholder() {
        let view = AppRemoteImage(url: nil)
            .placeholder { Text("Loading...") }
        #expect(type(of: view) == AppRemoteImage.self)
    }

    @MainActor @Test func appRemoteImageChainableModifiers() {
        let view = AppRemoteImage(url: "https://picsum.photos/id/1/300/300")
            .cornerRadius(16)
            .contentMode(.fit)
            .downsampling(size: CGSize(width: 100, height: 100))
        #expect(type(of: view) == AppRemoteImage.self)
    }

    // MARK: - ImageCacheBootstrap

    @Test func cacheBootstrapConfigure() {
        // 验证 configure 方法不会崩溃
        ImageCacheBootstrap.configure()
        #expect(Bool(true))
    }

    @Test func cacheBootstrapConfigureCustomValues() {
        ImageCacheBootstrap.configure(
            memoryCacheMB: 50,
            diskCacheMB: 200,
            cacheExpireDays: 3
        )
        #expect(Bool(true))
    }
}

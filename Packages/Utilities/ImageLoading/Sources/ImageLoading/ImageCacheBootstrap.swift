import Foundation

import Kingfisher

/// Kingfisher 全局缓存配置入口
///
/// 在 App 启动时调用一次 `configure()` 即可统一设置所有缓存参数。
/// Feature 包无需关心底层缓存细节。
///
/// 用法（在 App 的 `init()` 中）：
/// ```swift
/// ImageCacheBootstrap.configure()
/// ```
public enum ImageCacheBootstrap {

    /// 配置 Kingfisher 全局缓存
    /// - Parameters:
    ///   - memoryCacheMB: 内存缓存上限（MB），默认 100 MB
    ///   - diskCacheMB: 磁盘缓存上限（MB），默认 500 MB
    ///   - cacheExpireDays: 缓存过期天数，默认 7 天
    public static func configure(
        memoryCacheMB: Int = 100,
        diskCacheMB: Int = 500,
        cacheExpireDays: Int = 7
    ) {
        let cache = ImageCache.default

        // 内存缓存上限（字节）
        cache.memoryStorage.config.totalCostLimit = memoryCacheMB * 1024 * 1024

        // 磁盘缓存上限（字节）
        cache.diskStorage.config.sizeLimit = UInt(diskCacheMB) * 1024 * 1024

        // 缓存过期时间
        cache.diskStorage.config.expiration = .days(cacheExpireDays)
    }

    /// 预加载一组图片到缓存
    ///
    /// 在列表视图出现时预加载可见区域商品的图片 URL，提升滑动体验。
    /// Feature 包传入 URL 字符串数组即可，无需感知 Kingfisher 类型。
    ///
    /// - Parameter urls: 需要预加载的图片 URL 字符串数组
    public static func prefetchImages(urls: [String]) {
        let kingfisherURLs = urls.compactMap { URL(string: $0) }
        guard !kingfisherURLs.isEmpty else { return }
        ImagePrefetcher(urls: kingfisherURLs).start()
    }
}

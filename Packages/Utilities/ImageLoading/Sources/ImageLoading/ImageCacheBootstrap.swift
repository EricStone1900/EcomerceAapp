import Kingfisher
import Foundation

/// Global cache configuration for the image loading system.
///
/// Call ``configure()`` once at app launch (typically in `MyEcommerceApp.init()`)
/// to set up Kingfisher's memory and disk cache limits.
public struct ImageCacheBootstrap {

    // MARK: - Configure

    /// Configure the global Kingfisher image cache with sensible defaults.
    ///
    /// - Parameters:
    ///   - memoryCacheLimitMB: Maximum memory cache size in megabytes. Defaults to `100`.
    ///   - diskCacheLimitMB: Maximum disk cache size in megabytes. Defaults to `500`.
    ///   - cacheExpirationDays: Number of days before cached images expire. Defaults to `7`.
    @MainActor
    public static func configure(
        memoryCacheLimitMB: Int = 100,
        diskCacheLimitMB: Int = 500,
        cacheExpirationDays: Int = 7
    ) {
        let cache = ImageCache.default

        // Memory cache
        cache.memoryStorage.config.totalCostLimit = memoryCacheLimitMB * 1024 * 1024

        // Disk cache
        cache.diskStorage.config.sizeLimit = UInt(diskCacheLimitMB) * 1024 * 1024
        cache.diskStorage.config.expiration = .days(cacheExpirationDays)
    }
}

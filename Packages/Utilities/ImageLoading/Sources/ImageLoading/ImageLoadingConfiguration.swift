import SwiftUI
import Kingfisher

/// A configuration model for remote image loading and display.
///
/// Use `ImageLoadingConfiguration` to customize the default placeholder,
/// failure indicator, and display style of loaded images.
public struct ImageLoadingConfiguration: Sendable {

    // MARK: - Placeholder

    /// The color used as the default placeholder background while an image is loading.
    public var placeholderColor: AppRemoteImage.PlaceholderColor

    /// The system icon name used as the default failure indicator.
    public var failureIconName: String

    // MARK: - Display

    /// The transition duration (in seconds) for fade-in after a successful load.
    public var transitionDuration: TimeInterval

    // MARK: - Initializer

    public init(
        placeholderColor: AppRemoteImage.PlaceholderColor = .appBackground,
        failureIconName: String = "photo.badge.exclamationmark",
        transitionDuration: TimeInterval = 0.25
    ) {
        self.placeholderColor = placeholderColor
        self.failureIconName = failureIconName
        self.transitionDuration = transitionDuration
    }

    // MARK: - Default

    /// The default configuration shared across the app.
    public static let `default` = ImageLoadingConfiguration()
}

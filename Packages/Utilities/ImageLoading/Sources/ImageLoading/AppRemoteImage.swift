import SwiftUI
import Kingfisher

/// A SwiftUI view that loads and displays remote images.
///
/// `AppRemoteImage` is the single entry point for displaying remote images
/// across the entire app. It wraps Kingfisher's `KFImage` internally so that
/// feature packages never depend on Kingfisher directly.
///
/// ## Usage
///
/// ```swift
/// AppRemoteImage(url: product.imageUrl.flatMap(URL.init(string:)))
///     .placeholder { Color.appBackground }
///     .frame(width: 60, height: 60)
///     .designCornerRadius(.medium)
/// ```
///
/// ## Design
///
/// - All configuration methods return a **new** instance (immutable pattern).
/// - Default placeholder uses a light gray background.
/// - On failure or nil URL, a system SF Symbol icon is shown.
public struct AppRemoteImage: View {

    // MARK: - Placeholder Color

    /// Represents a placeholder background color.
    public enum PlaceholderColor: String, Sendable {
        case appBackground
        case gray
        case clear

        var swiftUIColor: Color {
            switch self {
            case .appBackground: return Color.gray.opacity(0.15)
            case .gray: return Color.gray.opacity(0.2)
            case .clear: return .clear
            }
        }
    }

    // MARK: - Properties

    private let url: URL?
    private var placeholderView: AnyView?
    private var failureView: AnyView?
    private var placeholderColor: PlaceholderColor
    private var transitionDuration: TimeInterval

    @State private var loadFailed: Bool = false

    // MARK: - Init

    /// Creates a remote image view for the given URL.
    /// - Parameter url: The remote image URL. Pass `nil` to show the placeholder.
    public init(url: URL?) {
        self.url = url
        self.placeholderView = nil
        self.failureView = nil
        self.placeholderColor = .appBackground
        self.transitionDuration = ImageLoadingConfiguration.default.transitionDuration
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Placeholder (shown while loading or when URL is nil)
            if url == nil {
                placeholderContent
            } else if loadFailed {
                failureContent
            } else {
                kingfisherContent
            }
        }
    }

    // MARK: - Kingfisher Content

    @ViewBuilder
    private var kingfisherContent: some View {
        KFImage.url(url)
            .placeholder { _ in
                placeholderContent
            }
            .onSuccess { _ in
                loadFailed = false
            }
            .onFailure { _ in
                loadFailed = true
            }
            .fade(duration: transitionDuration)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
    }

    // MARK: - Configuration (Immutable Pattern)

    /// Sets a custom placeholder view while the image is loading.
    public func placeholder<Placeholder: View>(@ViewBuilder _ content: () -> Placeholder) -> Self {
        with { $0.placeholderView = AnyView(content()) }
    }

    /// Sets a custom view to display on failure.
    public func onFailure<Content: View>(@ViewBuilder _ content: () -> Content) -> Self {
        with { $0.failureView = AnyView(content()) }
    }

    /// Sets the placeholder background color.
    public func placeholderColor(_ color: PlaceholderColor) -> Self {
        with { $0.placeholderColor = color }
    }

    /// Sets the fade-in transition duration.
    public func transition(duration: TimeInterval) -> Self {
        with { $0.transitionDuration = duration }
    }

    // MARK: - Private Helpers

    @ViewBuilder
    private var placeholderContent: some View {
        if let view = placeholderView {
            view
        } else {
            placeholderColor.swiftUIColor
        }
    }

    @ViewBuilder
    private var failureContent: some View {
        if let view = failureView {
            view
        } else {
            Image(systemName: ImageLoadingConfiguration.default.failureIconName)
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(placeholderColor.swiftUIColor)
        }
    }

    /// Returns a copy of `self` with the given mutation applied.
    private func `with`(_ mutate: (inout Self) -> Void) -> Self {
        var copy = self
        mutate(&copy)
        return copy
    }
}

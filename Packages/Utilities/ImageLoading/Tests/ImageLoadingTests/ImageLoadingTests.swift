import Testing
@testable import ImageLoading

@Test func appRemoteImageInitializesWithURL() {
    let url = URL(string: "https://picsum.photos/id/1/400/400")
    let image = AppRemoteImage(url: url)
    #expect(image != nil)
}

@Test func appRemoteImageInitializesWithNilURL() {
    let image = AppRemoteImage(url: nil)
    #expect(image != nil)
}

@Test func imageLoadingConfigurationDefaults() {
    let config = ImageLoadingConfiguration.default
    #expect(config.transitionDuration == 0.25)
    #expect(config.failureIconName == "photo.badge.exclamationmark")
}

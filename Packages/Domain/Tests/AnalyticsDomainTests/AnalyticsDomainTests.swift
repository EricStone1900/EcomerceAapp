import Testing

import AnalyticsAbstraction

@testable import AnalyticsDomain

// MARK: - Mock

final class MockAnalyticsWrapper: AnalyticsWrapperProtocol {

    var trackedEvents: [String] = []

    func trackEvent(_ event: String) {

        trackedEvents.append(event)
    }
}

// MARK: - Tests

@Test("TrackPageLifecycleUseCase calls trackEvent with page identifier and duration")
func testTrackPageLifecycle() {

    let mockWrapper = MockAnalyticsWrapper()
    let useCase = TrackPageLifecycleUseCase(analyticsWrapper: mockWrapper)

    useCase.start(pageIdentifier: "product_detail", duration: 5.0, extraParameters: nil)

    #expect(mockWrapper.trackedEvents.count == 1)
    #expect(mockWrapper.trackedEvents.first?.contains("page=product_detail") == true)
    #expect(mockWrapper.trackedEvents.first?.contains("duration=5.0") == true)
}

@Test("TrackPageLifecycleUseCase includes extra parameters when provided")
func testTrackPageLifecycleWithExtraParams() {

    let mockWrapper = MockAnalyticsWrapper()
    let useCase = TrackPageLifecycleUseCase(analyticsWrapper: mockWrapper)

    useCase.start(
        pageIdentifier: "cart",
        duration: 10.0,
        extraParameters: ["item_count": 3]
    )

    #expect(mockWrapper.trackedEvents.count == 1)
    let event = mockWrapper.trackedEvents.first!
    #expect(event.contains("page=cart") == true)
    #expect(event.contains("duration=10.0") == true)
    #expect(event.contains("item_count=3") == true)
}

@Test("TrackPageLifecycleUseCase handles empty extra parameters gracefully")
func testTrackPageLifecycleWithEmptyExtraParams() {

    let mockWrapper = MockAnalyticsWrapper()
    let useCase = TrackPageLifecycleUseCase(analyticsWrapper: mockWrapper)

    useCase.start(pageIdentifier: "settings", duration: 2.0, extraParameters: [:])

    #expect(mockWrapper.trackedEvents.count == 1)
    let event = mockWrapper.trackedEvents.first!
    #expect(event == "page=settings&duration=2.0")
}

import Foundation

import AnalyticsAbstraction

import DIAbstraction

final class TrackPageLifecycleUseCase: TrackPageLifecycleUseCaseProtocol {

    private let analyticsWrapper: AnalyticsWrapperProtocol

    init(analyticsWrapper: AnalyticsWrapperProtocol) {

        self.analyticsWrapper = analyticsWrapper
    }

    func start(pageIdentifier: String, duration: TimeInterval, extraParameters: [String: Any]?) {

        let paramString: String = {
            if let extra = extraParameters, !extra.isEmpty {
                let extraDesc = extra.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                return "page=\(pageIdentifier)&duration=\(duration)&\(extraDesc)"
            }
            return "page=\(pageIdentifier)&duration=\(duration)"
        }()

        analyticsWrapper.trackEvent(paramString)
    }
}

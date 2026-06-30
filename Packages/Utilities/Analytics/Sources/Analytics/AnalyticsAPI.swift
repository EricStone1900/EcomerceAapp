import Foundation
import API

enum AnalyticsAPI: APIRequestProtocol {
    case trackEvent(event: String)
}

extension AnalyticsAPI {
    var path: String { "/analytics/event" }
    var requestType: RequestType { .POST }
    var params: [String: Any] {
        switch self {
        case let .trackEvent(event):
            return ["event": event]
        }
    }
}

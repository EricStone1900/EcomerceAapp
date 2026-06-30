import Foundation

public struct RemoteWebDataSource {
    private let timeoutInterval: TimeInterval
    private let additionalHeaders: [String: String]

    public init(
        timeoutInterval: TimeInterval = 30,
        additionalHeaders: [String: String] = [:]
    ) {
        self.timeoutInterval = timeoutInterval
        self.additionalHeaders = additionalHeaders
    }

    public func buildRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        additionalHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
}

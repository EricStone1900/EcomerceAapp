import Foundation

public struct PhotoCaptureResult: Sendable {
    public let processedFileURL: URL
    public let rawFileURL: URL?

    public init(processedFileURL: URL, rawFileURL: URL?) {
        self.processedFileURL = processedFileURL
        self.rawFileURL = rawFileURL
    }
}

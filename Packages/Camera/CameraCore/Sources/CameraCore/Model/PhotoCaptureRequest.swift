public struct PhotoCaptureRequest: Sendable {
    public let captureRAW: Bool

    public init(captureRAW: Bool = false) {
        self.captureRAW = captureRAW
    }
}

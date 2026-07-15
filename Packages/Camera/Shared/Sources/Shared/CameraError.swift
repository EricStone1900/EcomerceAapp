import Foundation

public enum CameraError: Error, Sendable {
    case sessionConfigurationFailed(underlying: Error?)
    case deviceUnavailable(LensType)
    case permissionDenied
    case interrupted(reason: String)
    case captureFailed(underlying: Error?)
    case unsupportedControl(String)
}

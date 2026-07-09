import AVFoundation
import UIKit
import RxSwift

public enum PermissionStatus: Equatable {
    case notDetermined
    case granted
    case denied
}

public final class SpeechPermissionManager {

    public init() {}

    public var currentStatus: PermissionStatus {
        let status = AVAudioApplication.shared.recordPermission
        return switch status {
        case .undetermined: .notDetermined
        case .granted: .granted
        case .denied: .denied
        @unknown default: .denied
        }
    }

    public func requestPermission() -> Observable<PermissionStatus> {
        Observable.create { observer in
            AVAudioApplication.requestRecordPermission { granted in
                observer.onNext(granted ? .granted : .denied)
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }

    /// Open the system Settings app for this app's microphone permission.
    /// Typical usage: call this when the user needs to manually enable mic access.
    public static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

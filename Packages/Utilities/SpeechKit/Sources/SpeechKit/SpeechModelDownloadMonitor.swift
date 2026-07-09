import Foundation
import Network
import RxSwift

import SpeechAbstraction

/// Monitors the download status of speech models (ASR / TTS)
/// and provides network connectivity awareness.
public final class SpeechModelDownloadMonitor {

    /// Thread-safe box for the non-Sendable BehaviorSubject.
    private final class Box: @unchecked Sendable {
        let subject = BehaviorSubject<Bool>(value: true)
    }

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.speechkit.network", qos: .utility)
    private let box = Box()

    public init() {
        self.monitor = NWPathMonitor()
        let box = self.box
        monitor.pathUpdateHandler = { path in
            let isSatisfied = path.status == .satisfied
            box.subject.onNext(isSatisfied)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Observable that emits `true` when the network is available, `false` otherwise.
    public var isNetworkAvailable: Observable<Bool> {
        box.subject.asObservable()
    }

    /// Check whether a specific model directory exists locally.
    /// - Parameter modelPath: The expected local path for the model.
    /// - Returns: `.ready` if the directory exists, `.notDownloaded` otherwise.
    public func checkLocalModel(at modelPath: URL) -> SpeechModelDownloadStatus {
        FileManager.default.fileExists(atPath: modelPath.path)
            ? .ready
            : .notDownloaded
    }
}

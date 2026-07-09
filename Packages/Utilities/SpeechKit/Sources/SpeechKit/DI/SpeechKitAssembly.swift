import DIAbstraction
import SpeechAbstraction

extension DIContainer {

    @MainActor
    public static func registerSpeechKitASR() {
        DIContainer.shared.register(SpeechRecognizerProtocol.self) { _ in
            ParakeetSpeechRecognizer(
                permissionManager: SpeechPermissionManager()
            )
        }

        DIContainer.shared.register(SpeechPermissionManager.self) { _ in
            SpeechPermissionManager()
        }

        DIContainer.shared.register(SpeechModelDownloadMonitor.self) { _ in
            SpeechModelDownloadMonitor()
        }
    }

    @MainActor
    public static func registerSpeechKitTTS() {
        DIContainer.shared.register(SpeechSynthesizerProtocol.self) { _ in
            KokoroSpeechSynthesizer()
        }
    }
}

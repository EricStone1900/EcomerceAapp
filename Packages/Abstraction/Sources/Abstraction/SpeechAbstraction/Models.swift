public struct SpeechRecognitionResult: Equatable {
    public let text: String
    public let isFinal: Bool
    public let confidence: Float?

    public init(text: String, isFinal: Bool, confidence: Float?) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
    }
}

public enum SpeechVoiceOption: Equatable {
    case kokoro(String)
}

@MainActor
extension SpeechVoiceOption {
    public static let defaultFemale = SpeechVoiceOption.kokoro("af_heart")
    public static let defaultMale = SpeechVoiceOption.kokoro("am_bryce")
}

public enum SpeechPlaybackStatus: Equatable {
    case playing
    case finished
    case failed(EquatableError)
}

public enum SpeechModelDownloadStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case ready
    case failed(EquatableError)
}

/// Wrapper to make `Error` values equatable by comparing their localized descriptions.
public struct EquatableError: Error, Equatable {
    public let error: Error

    public init(_ error: Error) {
        self.error = error
    }

    public static func == (lhs: EquatableError, rhs: EquatableError) -> Bool {
        lhs.error.localizedDescription == rhs.error.localizedDescription
    }
}

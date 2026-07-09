import AVFoundation

/// Manages audio session categories to ensure ASR (voice search)
/// and TTS (playback) don't conflict.
public final class AudioSessionManager {

    public enum SessionMode {
        /// For voice search — record and play
        case voiceSearch
        /// For speech playback only
        case playback
    }

    public init() {}

    /// Configure the audio session for the given mode.
    public func configure(for mode: SessionMode) throws {
        let session = AVAudioSession.sharedInstance()
        switch mode {
        case .voiceSearch:
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        case .playback:
            try session.setCategory(.playback, mode: .default)
        }
        try session.setActive(true)
    }

    /// Deactivate the audio session.
    public func deactivate() throws {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

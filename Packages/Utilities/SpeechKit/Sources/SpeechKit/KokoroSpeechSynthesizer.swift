import Foundation
import AVFoundation
import RxSwift

import KokoroTTS
import SpeechAbstraction

/// Implementation of `SpeechSynthesizerProtocol` using the Kokoro TTS model.
///
/// Manages model loading, text-to-speech synthesis, and audio playback
/// via `AVAudioEngine`.
@MainActor
public final class KokoroSpeechSynthesizer: SpeechSynthesizerProtocol {

    /// Thread-safe wrapper around the non-Sendable KokoroTTSModel.
    private final class ModelBox: @unchecked Sendable {
        var model: KokoroTTSModel?
        /// Task that runs `KokoroTTSModel.fromPretrained()`. Set on first call; subsequent
        /// calls simply `await` its `value` instead of starting a second download.
        var loadTask: Task<Void, Error>?
    }

    private let modelBox = ModelBox()

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private let playbackSubject = PublishSubject<SpeechPlaybackStatus>()
    private let disposeBag = DisposeBag()
    private var playbackDisposable: Disposable?

    private let stateLock = NSLock()

    public init() {}

    // MARK: - Protocol

    public func speak(text: String, voice: SpeechVoiceOption) -> Observable<SpeechPlaybackStatus> {
        let voiceId: String = {
            if case .kokoro(let id) = voice { return id }
            return KokoroTTSModel.defaultVoice
        }()
        print("[KokoroSpeechSynthesizer] speak() text=\"\(text.prefix(50))...\" voice=\(voiceId)")

        // Kick off async work
        Task { [weak self] in
            await self?.performSynthesis(text: text, voiceId: voiceId)
        }

        return playbackSubject.asObservable()
            .do(onDispose: { [weak self] in
                print("[KokoroSpeechSynthesizer] Observable disposed — stopping playback")
                self?.stopPlayback()
            })
    }

    public func stopSpeaking() {
        print("[KokoroSpeechSynthesizer] stopSpeaking() called")
        stopPlayback()
    }

    // MARK: - Private

    private func performSynthesis(text: String, voiceId: String) async {
        print("[KokoroSpeechSynthesizer] performSynthesis started")
        do {
            // 1. Ensure model is loaded (with dedup via modelLoadTask)
            playbackSubject.onNext(.playing)
            print("[KokoroSpeechSynthesizer] loading model...")
            let model = try await loadModel()
            print("[KokoroSpeechSynthesizer] model loaded, synthesizing...")

            // 2. Synthesize audio
            print("[KokoroSpeechSynthesizer] calling model.synthesize()")
            let pcmFloats = try model.synthesize(
                text: text,
                voice: voiceId,
                language: "en",
                speed: 1.0
            )
            print("[KokoroSpeechSynthesizer] model.synthesize() returned \(pcmFloats.count) samples")

            guard !pcmFloats.isEmpty else {
                print("[KokoroSpeechSynthesizer] ERROR: empty audio from model")
                playbackSubject.onNext(.failed(EquatableError(SpeechSynthesisError.emptyAudio)))
                playbackSubject.onCompleted()
                return
            }

            // 3. Prepare audio format
            print("[KokoroSpeechSynthesizer] preparing AVAudioPCMBuffer for \(pcmFloats.count) frames")
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(KokoroTTSModel.outputSampleRate),
                channels: 1,
                interleaved: false
            )

            guard let format, let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(pcmFloats.count)
            ) else {
                print("[KokoroSpeechSynthesizer] ERROR: buffer creation failed")
                playbackSubject.onNext(.failed(EquatableError(SpeechSynthesisError.bufferCreationFailed)))
                playbackSubject.onCompleted()
                return
            }

            buffer.frameLength = buffer.frameCapacity
            if let channelData = buffer.floatChannelData?[0] {
                for i in 0..<pcmFloats.count {
                    channelData[i] = pcmFloats[i]
                }
            }

            // 4. Start engine and schedule playback
            print("[KokoroSpeechSynthesizer] starting playback engine")
            try startPlaybackEngine()

            print("[KokoroSpeechSynthesizer] scheduling buffer and waiting for playback completion")
            let status = await scheduleAndWait(buffer: buffer)
            print("[KokoroSpeechSynthesizer] playback finished with status: \(status)")
            playbackSubject.onNext(status)
            playbackSubject.onCompleted()

        } catch {
            print("[KokoroSpeechSynthesizer] ERROR: \(error)")
            playbackSubject.onNext(.failed(EquatableError(error)))
            playbackSubject.onCompleted()
        }
    }

    /// Load model once, deduplicate concurrent load requests.
    /// On `@MainActor`, `await` suspensions may allow a second `speak()` call
    /// to enter this method. We use a shared `Task` so both calls await the
    /// same download without starting it twice.
    private func loadModel() async throws -> KokoroTTSModel {
        if let model = modelBox.model {
            print("[KokoroSpeechSynthesizer] loadModel — returning cached model")
            return model
        }

        if let existingTask = modelBox.loadTask {
            print("[KokoroSpeechSynthesizer] loadModel — awaiting in-progress download task")
            try await existingTask.value
            if let model = modelBox.model { return model }
            throw SpeechSynthesisError.modelLoadFailed
        }

        print("[KokoroSpeechSynthesizer] loadModel — starting KokoroTTSModel.fromPretrained()")
        let task = Task<Void, Error> { [box = modelBox] in
//            let model = try await KokoroTTSModel.fromPretrained(offlineMode: true)
            let model = try await KokoroTTSModel.fromPretrained()
            box.model = model
        }
        modelBox.loadTask = task

        do {
            try await task.value
            guard let model = modelBox.model else {
                throw SpeechSynthesisError.modelLoadFailed
            }
            print("[KokoroSpeechSynthesizer] loadModel — model ready")
            modelBox.loadTask = nil
            return model
        } catch {
            print("[KokoroSpeechSynthesizer] loadModel — failed: \(error)")
            modelBox.loadTask = nil
            throw error
        }
    }

    /// Schedule a buffer and await playback completion using continuation.
    private func scheduleAndWait(buffer: AVAudioPCMBuffer) async -> SpeechPlaybackStatus {
        let player = playerNode
        return await withCheckedContinuation { continuation in
            player.scheduleBuffer(buffer) {
                DispatchQueue.main.async {
                    continuation.resume(returning: .finished)
                }
            }
            player.play()
        }
    }

    private func startPlaybackEngine() throws {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !audioEngine.isRunning else { return }

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
        try audioEngine.start()
    }

    private func stopPlayback() {
        stateLock.lock()
        defer { stateLock.unlock() }

        playerNode.stop()
        if audioEngine.isRunning {
            audioEngine.disconnectNodeInput(playerNode)
            audioEngine.stop()
        }
        playbackDisposable?.dispose()
        playbackDisposable = nil
    }
}

// MARK: - Errors

public enum SpeechSynthesisError: LocalizedError, Equatable {
    case deallocated
    case emptyAudio
    case bufferCreationFailed
    case modelLoadFailed

    public var errorDescription: String? {
        switch self {
        case .deallocated: "语音合成器已释放"
        case .emptyAudio: "生成的音频为空"
        case .bufferCreationFailed: "创建音频缓冲区失败"
        case .modelLoadFailed: "模型加载失败"
        }
    }
}

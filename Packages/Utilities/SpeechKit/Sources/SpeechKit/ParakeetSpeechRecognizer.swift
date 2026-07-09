import Foundation
import AVFoundation
import RxSwift

import SpeechAbstraction

/// Implementation of `SpeechRecognizerProtocol` using the Parakeet ASR model.
///
/// Manages microphone audio capture via `AVAudioEngine` and feeds audio buffers
/// into the Parakeet model for streaming speech recognition.
public final class ParakeetSpeechRecognizer: SpeechRecognizerProtocol {

    private let audioEngine = AVAudioEngine()
    private let permissionManager: SpeechPermissionManager

    /// Recreated on each `stopListening()` so repeated calls to `startListening()` always
    /// get a fresh subject rather than one left in a completed/errored state.
    private var recognizeSubject = PublishSubject<SpeechRecognitionResult>()
    private let disposeBag = DisposeBag()

    /// Whether the Parakeet model has been loaded and is ready for inference.
    /// Set this after model download completes.
    public var isModelReady: Bool = false

    public init(permissionManager: SpeechPermissionManager = SpeechPermissionManager()) {
        self.permissionManager = permissionManager
    }

    public func startListening() -> Observable<SpeechRecognitionResult> {
        print("[ParakeetSpeechRecognizer] startListening() called")
        // Chain: permission → model ready → audio engine → recognition results
        let permission = permissionManager.requestPermission()
            .do(onNext: { [weak self] status in
                print("[ParakeetSpeechRecognizer] permission status: \(status)")
                guard status == .granted else {
                    self?.recognizeSubject.onError(
                        SpeechPermissionError.denied
                    )
                    return
                }
            })
            .filter { $0 == .granted }
            .map { _ in }
            .do(onNext: { print("[ParakeetSpeechRecognizer] permission granted") })

        let startAudio = permission
            .flatMap { [weak self] (_: Void) -> Observable<Void> in
                guard let self else { return Observable.error(SpeechInternalError.deallocated) }
                print("[ParakeetSpeechRecognizer] starting audio engine")
                return self.startAudioEngine()
                    .do(onError: { (error: Error) in print("[ParakeetSpeechRecognizer] startAudioEngine error: \(error)") }, onCompleted: { print("[ParakeetSpeechRecognizer] startAudioEngine completed") })
            }
            .do(onError: { (error: Error) in print("[ParakeetSpeechRecognizer] startAudio error: \(error)") }, onCompleted: { print("[ParakeetSpeechRecognizer] startAudio completed") })

        let audioSubscription = startAudio
            .flatMap { [weak self] (_: Void) -> Observable<SpeechRecognitionResult> in
                guard let self else { return Observable.error(SpeechInternalError.deallocated) }
                print("[ParakeetSpeechRecognizer] audio engine running — listening for results")
                return self.recognizeSubject
                    .do(onError: { (error: Error) in print("[ParakeetSpeechRecognizer] recognizeSubject error: \(error)") }, onCompleted: { print("[ParakeetSpeechRecognizer] recognizeSubject completed") })
            }

        return audioSubscription
            .do(onDispose: { [weak self] in
                print("[ParakeetSpeechRecognizer] audioSubscription DISPOSED — stopping audio engine")
                self?.stopAudioEngine()
            })
    }

    public func stopListening() {
        print("[ParakeetSpeechRecognizer] stopListening() called")
        stopAudioEngine()
        recognizeSubject.onCompleted()
        // Create a fresh subject so the next startListening() call doesn't
        // subscribe to an already-completed subject.
        recognizeSubject = PublishSubject<SpeechRecognitionResult>()
    }

    // MARK: - Private

    private func startAudioEngine() -> Observable<Void> {
        print("[ParakeetSpeechRecognizer] startAudioEngine() — setting up AVAudioEngine")
        return Observable<Void>.create { [weak self] observer in
            guard let self else {
                observer.onError(SpeechInternalError.deallocated)
                return Disposables.create()
            }

            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
                try audioSession.setActive(true)
                print("[ParakeetSpeechRecognizer] audio session configured (.playAndRecord)")

                let inputNode = self.audioEngine.inputNode
                let inputFormat = inputNode.outputFormat(forBus: 0)
                print("[ParakeetSpeechRecognizer] installing tap on inputNode (format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch)")

                inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                    self?.processAudioBuffer(buffer)
                }

                try self.audioEngine.start()
                print("[ParakeetSpeechRecognizer] audioEngine started successfully")
                observer.onNext(())
                observer.onCompleted()
            } catch {
                print("[ParakeetSpeechRecognizer] audioEngine start failed: \(error)")
                observer.onError(SpeechInternalError.audioEngineStartFailed(error))
            }

            return Disposables.create { [weak self] in
                self?.stopAudioEngine()
            }
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // TODO: Plan 2 implementation — feed buffer to ParakeetASR model for inference.
        // For now, emit a placeholder result to verify the pipeline.
        #if DEBUG
        let sampleText = "语音识别功能准备就绪"
        let result = SpeechRecognitionResult(text: sampleText, isFinal: false, confidence: nil)
        print("[ParakeetSpeechRecognizer] processAudioBuffer — \(buffer.frameLength) frames, emitting placeholder: \"\(sampleText)\"")
        recognizeSubject.onNext(result)
        #endif
    }

    private func stopAudioEngine() {
        print("[ParakeetSpeechRecognizer] stopAudioEngine() called")
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            print("[ParakeetSpeechRecognizer] audioEngine stopped")
        }
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Errors

public enum SpeechPermissionError: LocalizedError, Equatable {
    case denied

    public var errorDescription: String? {
        switch self {
        case .denied: "麦克风权限被拒绝"
        }
    }
}

public enum SpeechInternalError: LocalizedError, Equatable {
    case deallocated
    case audioEngineStartFailed(Error?)

    public var errorDescription: String? {
        switch self {
        case .deallocated: "语音识别器已释放"
        case .audioEngineStartFailed: "音频引擎启动失败"
        }
    }

    public static func == (lhs: SpeechInternalError, rhs: SpeechInternalError) -> Bool {
        switch (lhs, rhs) {
        case (.deallocated, .deallocated): true
        case (.audioEngineStartFailed, .audioEngineStartFailed): true
        default: false
        }
    }
}

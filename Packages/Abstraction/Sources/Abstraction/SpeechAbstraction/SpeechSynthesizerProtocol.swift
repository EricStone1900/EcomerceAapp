import RxSwift

@MainActor
public protocol SpeechSynthesizerProtocol: AnyObject {
    func speak(text: String, voice: SpeechVoiceOption) -> Observable<SpeechPlaybackStatus>
    func stopSpeaking()
}

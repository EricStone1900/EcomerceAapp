import RxSwift

@MainActor
public protocol SpeechRecognizerProtocol: AnyObject {
    var isModelReady: Bool { get }
    func startListening() -> Observable<SpeechRecognitionResult>
    func stopListening()
}

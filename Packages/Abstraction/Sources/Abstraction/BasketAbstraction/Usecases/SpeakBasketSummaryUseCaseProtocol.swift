import Foundation

import RxSwift
import SpeechAbstraction

@MainActor
public protocol SpeakBasketSummaryUseCaseProtocol: AnyObject {
    func speakSummary() -> Observable<SpeechPlaybackStatus>
    func stopSpeaking()
}

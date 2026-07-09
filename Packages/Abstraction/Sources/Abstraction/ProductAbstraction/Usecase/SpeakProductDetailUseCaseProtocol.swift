import Foundation

import RxSwift
import SpeechAbstraction

@MainActor
public protocol SpeakProductDetailUseCaseProtocol: AnyObject {
    func speak(product: ProductDomainModelProtocol) -> Observable<SpeechPlaybackStatus>
    func stopSpeaking()
}

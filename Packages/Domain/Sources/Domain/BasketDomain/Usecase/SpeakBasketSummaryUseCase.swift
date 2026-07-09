import Foundation

import RxSwift

import BasketAbstraction
import SpeechAbstraction

@MainActor
public final class SpeakBasketSummaryUseCase: SpeakBasketSummaryUseCaseProtocol {

    private let speechSynthesizer: SpeechSynthesizerProtocol
    private let getBasketUseCase: GetBasketUseCaseProtocol

    private let disposeBag = DisposeBag()

    public init(
        speechSynthesizer: SpeechSynthesizerProtocol,
        getBasketUseCase: GetBasketUseCaseProtocol
    ) {
        self.speechSynthesizer = speechSynthesizer
        self.getBasketUseCase = getBasketUseCase
    }

    public func speakSummary() -> Observable<SpeechPlaybackStatus> {
        print("[SpeakBasketSummaryUseCase] speakSummary() called")
        return Observable.create { [weak self] observer in
            guard let self else {
                print("[SpeakBasketSummaryUseCase] self deallocated")
                observer.onCompleted()
                return Disposables.create()
            }

            let disposable = self.getBasketUseCase.start(userID: UUID())
                .take(1)
                .subscribe(onNext: { items in
                    print("[SpeakBasketSummaryUseCase] fetched \(items.count) basket items")
                    let script = self.buildScript(for: items)
                    print("[SpeakBasketSummaryUseCase] script built: \"\(script)\"")
                    guard !script.isEmpty else {
                        print("[SpeakBasketSummaryUseCase] script empty, skipping")
                        observer.onCompleted()
                        return
                    }
                    let playback = self.speechSynthesizer.speak(text: script, voice: .defaultFemale)
                    print("[SpeakBasketSummaryUseCase] calling SpeechSynthesizerProtocol.speak()")
                    playback.subscribe(onNext: { status in
                        print("[SpeakBasketSummaryUseCase] playback status: \(status)")
                        observer.onNext(status)
                    }, onError: { error in
                        print("[SpeakBasketSummaryUseCase] playback error: \(error)")
                        observer.onError(error)
                    }, onCompleted: {
                        print("[SpeakBasketSummaryUseCase] playback completed")
                        observer.onCompleted()
                    }).disposed(by: self.disposeBag)
                })

            return Disposables.create {
                print("[SpeakBasketSummaryUseCase] disposing — stopping speech")
                disposable.dispose()
                self.speechSynthesizer.stopSpeaking()
            }
        }
    }

    public func stopSpeaking() {
        speechSynthesizer.stopSpeaking()
    }

    // MARK: - Script Builder

    private func buildScript(for items: [BasketDomainModelProtocol]) -> String {
        guard !items.isEmpty else {
            return "您的购物车是空的"
        }

        let total = items.reduce(0.0) { $0 + $1.price * Double($1.quantity) }
        let totalItems = items.reduce(0) { $0 + $1.quantity }

        let maxItem = items.max { $0.price < $1.price }
        var parts: [String] = []

        parts.append("您的购物车共有 \(totalItems) 件商品")
        parts.append("总计 \(String(format: "%.2f", total)) 元")

        if let maxItem {
            let maxPrice = String(format: "%.2f", maxItem.price)
            parts.append("最贵的商品是「\(maxItem.productName)」\(maxPrice) 元")
        }

        return parts.joined(separator: "，")
    }
}

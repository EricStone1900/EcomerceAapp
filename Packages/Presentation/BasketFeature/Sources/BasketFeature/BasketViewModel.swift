import Foundation
import Combine
import RxSwift

import BasketAbstraction
import DIAbstraction

import Utils

@MainActor
public final class BasketViewModel: ObservableObject {

    @Published var baskets: [BasketDomainModelProtocol] = []
    @Published var isSpeaking: Bool = false

    private let getBasketUseCase: GetBasketUseCaseProtocol
    private let speakUseCase: SpeakBasketSummaryUseCaseProtocol

    private var cancellables = Set<AnyCancellable>()
    private let disposeBag = DisposeBag()

    public init() {

        self.getBasketUseCase = DIContainer.shared.resolve(GetBasketUseCaseProtocol.self)!
        self.speakUseCase = DIContainer.shared.resolve(SpeakBasketSummaryUseCaseProtocol.self)!
    }

    func getBasket(userId: UUID) {

        getBasketUseCase.start(userID: userId)
            .map { $0 }
            .asPublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: \.baskets, on: self)
            .store(in: &cancellables)

    }

    func calculateTotalPrice() -> Double {
         return baskets.reduce(0) { result, item in
            result + (item.price * Double(item.quantity))
        }
    }

    func speakSummary() {
        print("[BasketViewModel] speakSummary() called — injecting SpeakBasketSummaryUseCase")
        speakUseCase.speakSummary()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                print("[BasketViewModel] speakSummary status: \(status)")
                self?.isSpeaking = (status == .playing)
            }, onError: { [weak self] error in
                print("[BasketViewModel] speakSummary error: \(error)")
                self?.isSpeaking = false
            }, onCompleted: { [weak self] in
                print("[BasketViewModel] speakSummary completed")
                self?.isSpeaking = false
            })
            .disposed(by: disposeBag)
    }

    func stopSpeaking() {
        print("[BasketViewModel] stopSpeaking() called")
        speakUseCase.stopSpeaking()
        isSpeaking = false
    }

    func onDisappear() {
        print("[BasketViewModel] onDisappear — stopping speech")
        speakUseCase.stopSpeaking()
    }
}

import Foundation
import Combine

import RxSwift

import ProductAbstraction
import BasketAbstraction
import AnalyticsAbstraction
import DIAbstraction

import Utils

@MainActor
final class ItemDetailViewModel: ObservableObject {

    @Published var product: ProductDomainModelProtocol

    @Published var quantity: Int = 1

    @Published var isSpeaking: Bool = false

    private let addProductUseCase: AddProductUseCaseProtocol
    private let sendProductDetailAnalyticsDataUseCase: SendProductDetailAnalyticsDataUsecaseProtocol
    private let speakUseCase: SpeakProductDetailUseCaseProtocol

    private let userId: UUID

    private var cancellables = Set<AnyCancellable>()
    private let disposeBag = DisposeBag()

    init(
        product: ProductDomainModelProtocol,
        userId: UUID
    ) {

        self.product = product

        self.userId = userId

        addProductUseCase = DIContainer.shared.resolve(AddProductUseCaseProtocol.self)!
        sendProductDetailAnalyticsDataUseCase = DIContainer.shared.resolve(SendProductDetailAnalyticsDataUsecaseProtocol.self)!
        speakUseCase = DIContainer.shared.resolve(SpeakProductDetailUseCaseProtocol.self)!
    }

    func addProduct() {

        addProductUseCase.start(
            userID: userId,
            productId: product.id,
            quantity: quantity
        )
        .asPublisher()
        .sink(receiveValue: {})
        .store(in: &cancellables)

        sendProductDetailAnalyticsDataUseCase.start(data: "🚀 product added to basket successfully")
    }

    func speakProduct() {
        speakUseCase.speak(product: product)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                self?.isSpeaking = (status == .playing)
            }, onError: { [weak self] _ in
                self?.isSpeaking = false
            }, onCompleted: { [weak self] in
                self?.isSpeaking = false
            })
            .disposed(by: disposeBag)
    }

    func stopSpeaking() {
        speakUseCase.stopSpeaking()
        isSpeaking = false
    }

    func onDisappear() {
        speakUseCase.stopSpeaking()
    }
}

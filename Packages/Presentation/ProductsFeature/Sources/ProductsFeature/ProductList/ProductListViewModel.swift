import Foundation
import Combine

import RxSwift

import ProductAbstraction
import DIAbstraction

import Utils

@MainActor
final class ProductsListViewModel: ObservableObject {

    @Published var products: [ProductDomainModelProtocol] = []
    @Published var voiceSearchState: VoiceSearchState = .idle

    private let getProductsUseCase: GetProductsUseCaseProtocol
    private let voiceSearchUseCase: VoiceSearchProductsUseCaseProtocol

    private var cancellables = Set<AnyCancellable>()
    private let disposeBag = DisposeBag()

    /// Trigger for voice search — fire `.next(())` to start a voice search.
    private let voiceSearchTrigger = PublishSubject<Void>()

    init() {
        self.getProductsUseCase = DIContainer.shared.resolve(GetProductsUseCaseProtocol.self)!
        self.voiceSearchUseCase = DIContainer.shared.resolve(VoiceSearchProductsUseCaseProtocol.self)!

        subscribe()
    }

    // MARK: - Public API

    func startVoiceSearch() {
        print("[ProductsListViewModel] startVoiceSearch() called — firing voiceSearchTrigger")
        voiceSearchTrigger.onNext(())
    }

    func cancelVoiceSearch() {
        print("[ProductsListViewModel] cancelVoiceSearch() called")
        voiceSearchUseCase.cancel()
        voiceSearchState = .idle
    }

    /// Stop voice search and process the last recognized text to search products.
    func stopVoiceSearch() {
        print("[ProductsListViewModel] stopVoiceSearch() called")
        voiceSearchUseCase.stopAndProcess()
    }

    // MARK: - Private

    private func subscribe() {
        // Normal product list
        getProductsUseCase.start()
            .asPublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: \.products, on: self)
            .store(in: &cancellables)

        // Voice search pipeline
        print("[ProductsListViewModel] subscribe — setting up voice search pipeline")
        voiceSearchUseCase.execute(trigger: voiceSearchTrigger)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                print("[ProductsListViewModel] voiceSearchState → \(state)")
                self?.voiceSearchState = state
            })
            .disposed(by: disposeBag)
    }
}

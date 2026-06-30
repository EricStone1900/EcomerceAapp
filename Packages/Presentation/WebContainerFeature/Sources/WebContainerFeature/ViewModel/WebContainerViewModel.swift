import Foundation
import Combine
import RxSwift

import WebContainerAbstraction
import DIAbstraction

import Utils

@MainActor public final class WebContainerViewModel: ObservableObject {

    @Published public var isLoading: Bool = false
    @Published public var loadInstruction: WebLoadInstruction? = nil
    @Published public var error: Error? = nil

    public let loadWebContent: (WebContent) -> Void
    public let handleBridgeCommand: (WebBridgeCommand) -> Void

    private let loadUseCase: LoadWebContentUseCaseProtocol
    private let bridgeUseCase: ProcessBridgeCommandUseCaseProtocol
    private let disposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()

    public init(bridgeRouter: NativeBridgeRouter) {

        let loadSubject = PublishSubject<WebContent>()
        let bridgeSubject = PublishSubject<WebBridgeCommand>()

        loadWebContent = { loadSubject.onNext($0) }
        handleBridgeCommand = { bridgeSubject.onNext($0) }

        loadUseCase = DIContainer.shared.resolve(LoadWebContentUseCaseProtocol.self)!
        bridgeUseCase = DIContainer.shared.resolve(ProcessBridgeCommandUseCaseProtocol.self)!

        loadSubject
            .do(onNext: { [weak self] _ in self?.isLoading = true })
            .flatMapLatest { [weak self] content in
                self?.loadUseCase.execute(content: content) ?? .empty()
            }
            .observe(on: MainScheduler.instance)
            .asPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let err) = completion { self?.error = err }
                },
                receiveValue: { [weak self] instruction in
                    self?.isLoading = false
                    self?.loadInstruction = instruction
                }
            )
            .store(in: &cancellables)

        bridgeSubject
            .flatMapLatest { [weak self] command in
                self?.bridgeUseCase.execute(command: command) ?? .empty()
            }
            .observe(on: MainScheduler.instance)
            .asPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { action in bridgeRouter.dispatch(action) }
            )
            .store(in: &cancellables)
    }
}

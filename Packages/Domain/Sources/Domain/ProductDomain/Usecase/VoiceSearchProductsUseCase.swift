import ProductAbstraction
import RxSwift
import SpeechAbstraction

@MainActor
public final class VoiceSearchProductsUseCase: VoiceSearchProductsUseCaseProtocol {

    private let speechRecognizer: SpeechRecognizerProtocol
    private let productRepository: ProductRepositoryProtocol

    private let disposeBag = DisposeBag()

    /// Tracks the last recognized text so it can be used when the recognizer stops.
    private var lastInterimText: String = ""

    public init(
        speechRecognizer: SpeechRecognizerProtocol,
        productRepository: ProductRepositoryProtocol
    ) {
        self.speechRecognizer = speechRecognizer
        self.productRepository = productRepository
    }

    /// Cancel an ongoing voice search and stop listening. Clears any captured text
    /// so the concat fallback in `startVoiceSearch()` emits `.idle` instead of processing.
    public func cancel() {
        print("[VoiceSearchProductsUseCase] cancel() — stopping recognizer")
        lastInterimText = ""
        speechRecognizer.stopListening()
    }

    /// Stop the recognizer and trigger search with whatever text was last recognized.
    /// The concat fallback in `startVoiceSearch()` picks up `lastInterimText` automatically.
    public func stopAndProcess() {
        print("[VoiceSearchProductsUseCase] stopAndProcess() — stopping recognizer, will auto-search")
        speechRecognizer.stopListening()
    }

    /// Start the voice search pipeline.
    /// - Parameter trigger: An observable that fires once per voice search request.
    /// - Returns: Observable emitting state transitions throughout the flow.
    public func execute(trigger: Observable<Void>) -> Observable<VoiceSearchState> {
        print("[VoiceSearchProductsUseCase] execute() — setting up trigger subscription")
        return trigger
            .flatMapLatest { [weak self] _ -> Observable<VoiceSearchState> in
                guard let self else { return .just(.idle) }
                print("[VoiceSearchProductsUseCase] trigger fired — starting voice search")
                return self.startVoiceSearch()
            }
    }

    // MARK: - Private

    private func startVoiceSearch() -> Observable<VoiceSearchState> {
        print("[VoiceSearchProductsUseCase] startVoiceSearch() — calling speechRecognizer.startListening()")
        return speechRecognizer.startListening()
            .map { [weak self] result -> VoiceSearchState in
                guard let self else { return .idle }
                self.lastInterimText = result.text
                if result.isFinal {
                    print("[VoiceSearchProductsUseCase] ← final result: \"\(result.text)\" → .processing")
                    return .processing(text: result.text)
                }
                print("[VoiceSearchProductsUseCase] ← interim: \"\(result.text)\" → .listening")
                return .listening(interimText: result.text)
            }
            .concat(Observable.deferred { [weak self] in
                // When the recognizer stops (e.g. via stopAndProcess), the recognition
                // Observable completes. The concat fallback emits .processing with the
                // last recognized text, or .idle if there was no speech.
                guard let self else { return .just(.idle) }
                guard !self.lastInterimText.isEmpty else {
                    print("[VoiceSearchProductsUseCase] concat — no speech detected, emitting .idle")
                    return .just(.idle)
                }
                print("[VoiceSearchProductsUseCase] concat — recognizer stopped, searching for \"\(self.lastInterimText)\"")
                return .just(.processing(text: self.lastInterimText))
            })
            .startWith(.preparing)
            .flatMapLatest { [weak self] state -> Observable<VoiceSearchState> in
                guard let self else { return .just(state) }
                if case .processing(let query) = state {
                    print("[VoiceSearchProductsUseCase] final result received — searching for \"\(query)\"")
                    return self.searchProducts(query: query)
                }
                return .just(state)
            }
            .catch { error in
                print("[VoiceSearchProductsUseCase] error in voice search pipeline: \(error)")
                return .just(.idle)
            }
    }

    private func searchProducts(query: String) -> Observable<VoiceSearchState> {
        print("[VoiceSearchProductsUseCase] searchProducts — fetching all products and filtering for \"\(query)\"")
        return productRepository.fetchAll()
            .map { products in
                let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
                let filtered = products.filter { product in
                    product.name.lowercased().contains(lowerQuery)
                }
                if filtered.isEmpty {
                    print("[VoiceSearchProductsUseCase] searchProducts — no results for \"\(query)\"")
                    return .noResults(query: query)
                }
                print("[VoiceSearchProductsUseCase] searchProducts — found \(filtered.count) results")
                return .results(filtered)
            }
            .catch { error in
                print("[VoiceSearchProductsUseCase] searchProducts — fetch error: \(error)")
                return .just(.idle)
            }
    }
}

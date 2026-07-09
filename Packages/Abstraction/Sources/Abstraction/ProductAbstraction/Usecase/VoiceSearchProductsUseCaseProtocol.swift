import Foundation

import RxSwift

/// State model for the voice search flow.
public enum VoiceSearchState: Equatable {
    case idle
    case preparing
    case listening(interimText: String)
    case processing(text: String)
    case results([ProductDomainModelProtocol])
    case noResults(query: String)

    public static func == (lhs: VoiceSearchState, rhs: VoiceSearchState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): true
        case (.preparing, .preparing): true
        case (.listening(let a), .listening(let b)): a == b
        case (.processing(let a), .processing(let b)): a == b
        case (.results, .results): true
        case (.noResults(let a), .noResults(let b)): a == b
        default: false
        }
    }
}

@MainActor
public protocol VoiceSearchProductsUseCaseProtocol: AnyObject {
    func execute(trigger: Observable<Void>) -> Observable<VoiceSearchState>
    func cancel()
    /// Stop the recognizer and trigger search with the last recognized text.
    func stopAndProcess()
}

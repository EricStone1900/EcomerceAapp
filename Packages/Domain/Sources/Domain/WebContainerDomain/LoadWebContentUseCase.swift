import Foundation
import RxSwift

import WebContainerAbstraction

public final class LoadWebContentUseCase: LoadWebContentUseCaseProtocol {
    private let repository: WebContentRepositoryProtocol

    public init(repository: WebContentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(content: WebContent) -> Observable<WebLoadInstruction> {
        repository.resolveInstruction(for: content)
    }
}

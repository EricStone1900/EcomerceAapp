import Foundation

import WebContainerAbstraction
import DIAbstraction

extension DIContainer {

    @MainActor
    public static func registerLoadWebContentUseCase() {

        DIContainer.shared.register(LoadWebContentUseCaseProtocol.self) { _ in

            let repo = DIContainer.shared.resolve(WebContentRepositoryProtocol.self)!

            return LoadWebContentUseCase(repository: repo)
        }
    }

    @MainActor
    public static func registerProcessBridgeCommandUseCase() {

        DIContainer.shared.register(ProcessBridgeCommandUseCaseProtocol.self) { _ in

            let ruleRepo = DIContainer.shared.resolve(WebBridgeRuleRepositoryProtocol.self)!

            return ProcessBridgeCommandUseCase(ruleRepository: ruleRepo)
        }
    }
}

import Foundation

import DIAbstraction

import RoutingAbstraction

extension DIContainer {

    @MainActor
    public static func registerNavigateUseCase() {

        DIContainer.shared.register(NavigateUseCaseProtocol.self) { _ in

            let router = DIContainer.shared.resolve(RouterProtocol.self)

            return NavigateUseCase(router: router!)
        }

    }
}

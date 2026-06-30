import Foundation

import API
import DIAbstraction

extension DIContainer {

    @MainActor public static func registerAPIProvider() {

        DIContainer.shared.register(APIProviderProtocol.self) { _ in
            switch EnvironmentManager.current {
            case .prd:
                return APIProvider()
            case .dev:
                return MockAPIProvider()
            }
        }
    }
}

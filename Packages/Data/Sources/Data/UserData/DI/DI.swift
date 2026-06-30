import Foundation

import DIAbstraction

import API
import UserAbstraction

public extension DIContainer {

    @MainActor static func registerUserService() {

        DIContainer.shared.register(UserService.self) { _ in

            let provider = DIContainer.shared.resolve(APIProviderProtocol.self)!
            return UserService(apiProvider: provider)
        }
    }
}

extension DIContainer {

    @MainActor public static func registerUserRepository() {

        DIContainer.shared.register(UserRepositoryProtocol.self) { _ in

            let service = DIContainer.shared.resolve(UserService.self)

            return UserRepository(userService: service!)
        }
    }
}

import Foundation

import DIAbstraction

import AnalyticsAbstraction

import API

extension DIContainer {

    @MainActor
    public static func registerAnalyticsWrapper() {

        DIContainer.shared.register(AnalyticsWrapperProtocol.self) { _ in
            let provider = DIContainer.shared.resolve(APIProviderProtocol.self)!
            return AnalyticsWrapper(apiProvider: provider)
        }
    }
}

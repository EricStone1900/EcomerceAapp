import Foundation

import DIAbstraction

import API
import ProductAbstraction

extension DIContainer {

    @MainActor public static func registerProductService() {

        DIContainer.shared.register(ProductService.self) { _ in

            let provider = DIContainer.shared.resolve(APIProviderProtocol.self)!
            return ProductService(apiProvider: provider)
        }
    }
}


extension DIContainer {

    @MainActor public static func registerProductRepository() {

        DIContainer.shared.register(ProductRepositoryProtocol.self) { _ in

            let service = DIContainer.shared.resolve(ProductService.self)

            return ProductRepository(productService: service!)
        }
    }
}

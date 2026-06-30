import Foundation

import RxSwift

import API
import ProductAbstraction
 
public struct ProductService {

    private let apiProvider: APIProviderProtocol

    init(apiProvider: APIProviderProtocol = APIProvider()) {
        self.apiProvider = apiProvider
    }

    func getProducts() -> Observable<[ProductDTO]> {
        
        apiProvider
            .perform(ProductAPI.getProducts)
            .map([ProductDTO].self)
    }
}


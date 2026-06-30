import Foundation

import RxSwift

import API
 
public struct BasketService {

    private let apiProvider: APIProviderProtocol

    init(apiProvider: APIProviderProtocol = APIProvider()) {
        self.apiProvider = apiProvider
    }

    public func addProduct(
        userID: UUID,
        productId: UUID,
        quantity: Int
    ) -> Observable<Void> {
        
        apiProvider
            .perform(
                BasketAPI.addProduct(
                    userID: userID,
                    productId: productId,
                    quantity: quantity
                )
            )
            .map { _ in () }
    }
    
    func getBasket(userID: UUID) -> Observable<[BasketItemDTO]> {
        
        apiProvider
            .perform(BasketAPI.getBasket(userID: userID))
            .map([BasketItemDTO].self)
    }
}


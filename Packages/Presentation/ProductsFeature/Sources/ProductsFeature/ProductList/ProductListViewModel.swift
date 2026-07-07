import Foundation
import Combine

import ProductAbstraction
import DIAbstraction

import Utils

@MainActor
final class ProductsListViewModel: ObservableObject {
    
    @Published var products: [ProductDomainModelProtocol] = []
    
    private let getProductsUseCase: GetProductsUseCaseProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        
        self.getProductsUseCase = DIContainer.shared.resolve(GetProductsUseCaseProtocol.self)!

        subscribe()
    }
    
    private func subscribe() {
        
        getProductsUseCase.start()
            .asPublisher()
            .receive(on: DispatchQueue.main)
            .print("Products数据流 \(products)")
            .assign(to: \.products, on: self)
            .store(in: &cancellables)
        
    }
}

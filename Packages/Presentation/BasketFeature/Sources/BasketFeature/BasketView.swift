import SwiftUI

import DesignSystem

public struct BasketView: View {
    
    @StateObject var viewModel: BasketViewModel = BasketViewModel()
    
    let userId: UUID
    
    public init(userId: UUID) {
        
        self.userId = userId
    }
    
    public var body: some View {
        VStack {
            
            if viewModel.baskets.isEmpty {
                Text ("Your cart is empty")
                    .designPadding(.l)
            } else {
                List {
                    ForEach(viewModel.baskets, id: \.id) { basket in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(basket.productName)
                                    .font(.appHeadline)
                                Text("price: \(String(format:"%.2f", basket.price))")
                                    .font(.appSubheadline)
                            }
                            Spacer()
                            Text("Quantity: \(basket.quantity)")
                            Spacer()
                            Text(String(format:"%.2f", basket.price * Double(basket.quantity)))
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                HStack {
                    Spacer()
                    Text("Total: \(String(format:"%.2f", viewModel.calculateTotalPrice()))")
                        .font(.appTitle2)
                        .designPadding(.l)
                }
            }
        }
        .onAppear {
            viewModel.getBasket(userId: userId)
        }
    }
}

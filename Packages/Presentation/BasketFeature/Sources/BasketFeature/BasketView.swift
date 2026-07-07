import SwiftUI

import DesignSystem
import ImageLoading

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
                        HStack(spacing: .spacingM) {
                            AppRemoteImage(url: basket.imageUrl.flatMap(URL.init(string:)))
                                .placeholder { Color.gray.opacity(0.15) }
                                .frame(width: 50, height: 50)
                                .designCornerRadius(.medium)

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

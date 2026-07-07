import SwiftUI

import DesignSystem
import ImageLoading

public struct ProductListView: View {

    @StateObject var productsListViewModel = ProductsListViewModel()

    var userId: UUID

    public init(userId: UUID) {

        self.userId = userId
    }

    public var body: some View {

        NavigationView {
            List(
                productsListViewModel.products,
                id: \.id
            ) { product in
                NavigationLink(
                    destination: ItemDetailView(viewModel: ItemDetailViewModel(product: product, userId: userId))
                ) {
                    HStack(spacing: .spacingM) {
                        AppRemoteImage(url: product.imageUrl.flatMap(URL.init(string:)))
                            .placeholder { Color.gray.opacity(0.15) }
                            .frame(width: 60, height: 60)
                            .designCornerRadius(.medium)

                        VStack(alignment: .leading) {
                            Text(product.name)
                                .font(.appHeadline)
                            Text(String(format: "%.2f €", product.price))
                                .font(.appSubheadline)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }
            }
            .navigationTitle("Products")
        }
    }
}

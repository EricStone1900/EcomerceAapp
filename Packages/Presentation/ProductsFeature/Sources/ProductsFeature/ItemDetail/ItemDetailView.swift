import SwiftUI

import DesignSystem
import ProductAbstraction
import ImageLoading

struct ItemDetailView: View {

    @State private var quantity = 1

    @ObservedObject var viewModel: ItemDetailViewModel

    var body: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: .spacingM) {

                AppRemoteImage(url: viewModel.product.imageUrl.flatMap(URL.init(string:)))
                    .placeholder { ProgressView() }
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
                    .designCornerRadius(.large)
                    .clipped()

                Text(viewModel.product.name)
                    .font(.appTitle)

                Text(viewModel.product.description)
                    .font(.appBody)

                Text("\(String(format: "%.2f €", viewModel.product.price))")
                    .font(.appCallout)
                    .bold()

                Stepper("Quantity : \(viewModel.quantity)", value: $viewModel.quantity, in: 1...viewModel.product.quantity)

                Spacer()

                Button("Add to Basket") {

                    viewModel.addProduct()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .designPadding(.l)
        }
    }
}

import SwiftUI

import DesignSystem
import ProductAbstraction

struct ItemDetailView: View {

    @State private var quantity = 1

    @ObservedObject var viewModel: ItemDetailViewModel

    var body: some View {

        VStack {
            VStack(alignment: .leading, spacing: .spacingM) {

                Text(viewModel.product.name)
                    .font(.appTitle)

                Text(viewModel.product.description)
                    .font(.appBody)

                Text("\(String(format: "%.2f €", viewModel.product.price))")
                    .font(.appCallout)
                    .bold()

                Stepper("Quantity : \(viewModel.quantity)", value: $viewModel.quantity, in: 1...viewModel.product.quantity)

            }

            Spacer()

            Button("Add to Basket") {

                viewModel.addProduct()
            }
            .buttonStyle(.borderedProminent)
        }
        .designPadding(.l)
    }
}

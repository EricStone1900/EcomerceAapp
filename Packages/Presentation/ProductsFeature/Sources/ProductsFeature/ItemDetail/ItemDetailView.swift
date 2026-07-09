import SwiftUI

import DesignSystem
import ImageLoading
import ProductAbstraction

struct ItemDetailView: View {

    @State private var quantity = 1

    @ObservedObject var viewModel: ItemDetailViewModel

    var body: some View {

        VStack {
            AppRemoteImage(url: viewModel.product.imageURL)
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: .spacingM) {

                HStack {
                    Text(viewModel.product.name)
                        .font(.appTitle)

                    Spacer()

                    // Speak button
                    Button(action: {
                        if viewModel.isSpeaking {
                            viewModel.stopSpeaking()
                        } else {
                            viewModel.speakProduct()
                        }
                    }) {
                        Image(systemName: viewModel.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                            .foregroundColor(.appPrimary)
                            .font(.appTitle2)
                    }
                }

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
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

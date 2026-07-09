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
            VStack(spacing: 0) {
                // Voice search status bar
                voiceSearchBar

                // Product list
                List(
                    productsListViewModel.products,
                    id: \.id
                ) { product in
                    NavigationLink(
                        destination: ItemDetailView(viewModel: ItemDetailViewModel(product: product, userId: userId))
                    ) {
                        HStack(spacing: .spacingM) {
                            AppRemoteImage(url: product.imageURL)
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)

                            VStack(alignment: .leading) {
                                Text(product.name)
                                    .font(.appHeadline)
                                Text(String(format: "%.2f €", product.price))
                                    .font(.appSubheadline)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    microphoneButton
                }
            }
        }
    }

    // MARK: - Voice Search Views

    @ViewBuilder
    private var voiceSearchBar: some View {
        let state = productsListViewModel.voiceSearchState
        Group {
            switch state {
            case .idle:
                EmptyView()

            case .preparing:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("准备中...")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                .designPadding(.s)
                .frame(maxWidth: .infinity)

            case .listening(let interimText):
                HStack(spacing: .spacingS) {
                    Circle()
                        .fill(Color.appError)
                        .frame(width: 10, height: 10)
                        .opacity(0.7)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("聆听中...")
                            .font(.appCaption)
                            .foregroundColor(.appError)
                        if !interimText.isEmpty {
                            Text("\"\(interimText)\"")
                                .font(.appCallout)
                                .foregroundColor(.appTextPrimary)
                        }
                    }

                    Spacer()

                    Button("取消") {
                        productsListViewModel.cancelVoiceSearch()
                    }
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
                }
                .designPadding(.s)
                .background(Color.appWarning.opacity(0.1))

            case .processing(let text):
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在搜索 \"\(text)\"...")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                }
                .designPadding(.s)
                .frame(maxWidth: .infinity)

            case .results:
                // Results show in the main product list — nothing extra to display in the bar
                EmptyView()

            case .noResults(let query):
                HStack {
                    Text("未找到与「\(query)」相关的商品")
                        .font(.appCaption)
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    Button("关闭") {
                        productsListViewModel.cancelVoiceSearch()
                    }
                    .font(.appCaption)
                }
                .designPadding(.s)
                .background(Color.appWarning.opacity(0.1))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var microphoneButton: some View {
        Image(systemName: "mic.fill")
            .foregroundColor(.appPrimary)
            .onLongPressGesture(
                minimumDuration: 0,
                pressing: { isPressing in
                    if isPressing {
                        print("[ProductListView] microphoneButton pressed — starting voice search")
                        productsListViewModel.startVoiceSearch()
                    } else {
                        print("[ProductListView] microphoneButton released — stopping and processing")
                        productsListViewModel.stopVoiceSearch()
                    }
                },
                perform: {}
            )
    }
}

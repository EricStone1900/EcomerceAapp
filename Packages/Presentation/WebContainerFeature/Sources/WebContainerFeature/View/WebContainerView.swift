import SwiftUI

import WebContainerAbstraction

public struct WebContainerView: View {
    @ObservedObject private var viewModel: WebContainerViewModel
    private let messageHandler: WebScriptMessageHandler

    public init(viewModel: WebContainerViewModel, messageHandler: WebScriptMessageHandler) {
        self.viewModel = viewModel
        self.messageHandler = messageHandler
    }

    public var body: some View {
        ZStack {
            WKWebViewRepresentable(
                messageHandler: messageHandler,
                instruction: $viewModel.loadInstruction
            )

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .alert(
            "加载失败",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            ),
            actions: { Button("确认", role: .cancel) {} },
            message: { Text(viewModel.error?.localizedDescription ?? "") }
        )
    }
}

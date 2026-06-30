import SwiftUI
import WebKit

import WebContainerAbstraction

public struct WKWebViewRepresentable: UIViewRepresentable {
    private let messageHandler: WebScriptMessageHandler
    @Binding var instruction: WebLoadInstruction?

    public init(
        messageHandler: WebScriptMessageHandler,
        instruction: Binding<WebLoadInstruction?>
    ) {
        self.messageHandler = messageHandler
        self._instruction = instruction
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(messageHandler, name: "nativeBridge")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        guard let instruction else { return }
        switch instruction {
        case .loadRequest(let request):
            webView.load(request)
        case .loadFile(let fileURL, let accessURL):
            webView.loadFileURL(fileURL, allowingReadAccessTo: accessURL)
        case .loadHTML(let html, let baseURL):
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator: NSObject, WKNavigationDelegate {}
}

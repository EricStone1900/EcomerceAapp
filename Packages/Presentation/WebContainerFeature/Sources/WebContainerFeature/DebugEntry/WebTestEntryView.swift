import SwiftUI
import UIKit

import DIAbstraction
import WebContainerAbstraction

/// WebTest Tab 的根页面。
/// 加载本地测试 HTML，验证 WebContainer Bridge 的各项能力。
public struct WebTestEntryView: View {

    @StateObject private var viewModel: WebContainerViewModel
    @State private var handler: WebScriptMessageHandler

    public init() {
        let vm = DIContainer.shared.resolve(WebContainerViewModel.self)!
        let handler = WebScriptMessageHandler(onCommand: vm.handleBridgeCommand)
        _viewModel = StateObject(wrappedValue: vm)
        _handler = State(initialValue: handler)
    }

    public var body: some View {
        ZStack {
            WebContainerView(viewModel: viewModel, messageHandler: handler)

            // NavigationStack 捕获器：在视图出现时获取 UINavigationController
            NavigationControllerCapture { navController in
                let router = DIContainer.shared.resolve(NativeBridgeRouter.self)!
                router.setNavigationController(navController)
            }
            .frame(width: 0, height: 0)
            .hidden()
        }
        .onAppear {
            viewModel.loadWebContent(
                .localFile(fileName: "webtest.html", bundle: .module)
            )
        }
    }
}

// MARK: - NavigationControllerCapture

/// 通过 UIViewControllerRepresentable 从 SwiftUI 视图层级中捕获 UINavigationController。
private struct NavigationControllerCapture: UIViewControllerRepresentable {

    let onCapture: (UINavigationController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        CapturingViewController(onCapture: onCapture)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class CapturingViewController: UIViewController {
    let onCapture: (UINavigationController) -> Void
    private var hasCaptured = false

    init(onCapture: @escaping (UINavigationController) -> Void) {
        self.onCapture = onCapture
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasCaptured else { return }
        hasCaptured = true

        // 向上遍历视图层级找到 UINavigationController
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let navController = next as? UINavigationController {
                onCapture(navController)
                return
            }
            responder = next
        }
    }
}

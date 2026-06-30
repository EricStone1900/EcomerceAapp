import WebKit

import WebContainerAbstraction

public final class WebScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let onCommand: (WebBridgeCommand) -> Void

    public init(onCommand: @escaping (WebBridgeCommand) -> Void) {
        self.onCommand = onCommand
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "nativeBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String
        else { return }

        let command = WebBridgeCommand(
            action: action,
            target: body["target"] as? String,
            params: body["params"] as? [String: Any] ?? [:]
        )
        onCommand(command)
    }
}

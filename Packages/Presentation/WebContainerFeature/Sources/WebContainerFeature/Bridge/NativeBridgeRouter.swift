import UIKit

import WebContainerAbstraction

public final class NativeBridgeRouter {
    private weak var navigationController: UINavigationController?
    private let routeFactory: WebRouteFactoryProtocol

    private var customFunctionHandlers: [String: ([String: Any]) -> Void] = [:]

    public init(
        navigationController: UINavigationController?,
        routeFactory: WebRouteFactoryProtocol
    ) {
        self.navigationController = navigationController
        self.routeFactory = routeFactory
    }

    public func dispatch(_ action: NativeBridgeAction) {
        switch action {
        case .pushRoute(let route, let params):
            guard let vc = routeFactory.makeViewController(route: route, params: params) else {
                let alert = UIAlertController(
                    title: "路由错误",
                    message: "找不到对应 VC: \(route)",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "确认", style: .default))
                if let nav = navigationController {
                    nav.present(alert, animated: true)
                } else if let topVC = Self.topmostViewController() {
                    topVC.present(alert, animated: true)
                }
                return
            }
            if let nav = navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                vc.modalPresentationStyle = .pageSheet
                if let topVC = Self.topmostViewController() {
                    topVC.present(vc, animated: true)
                }
            }
        case .presentSheet(let route, let params):
            guard let vc = routeFactory.makeViewController(route: route, params: params) else { return }
            vc.modalPresentationStyle = .pageSheet
            navigationController?.present(vc, animated: true)
        case .dismiss:
            navigationController?.dismiss(animated: true)
        case .openCamera:
            break
        case .requestLocation:
            break
        case .shareContent(let text):
            let activity = UIActivityViewController(
                activityItems: [text], applicationActivities: nil
            )
            navigationController?.present(activity, animated: true)
        case .showAlert(let title, let message):
            let alert = UIAlertController(
                title: title, message: message, preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确认", style: .default))
            navigationController?.present(alert, animated: true)
        case .callFunction(let name, let params):
            customFunctionHandlers[name]?(params)
        case .none:
            break
        }
    }

    public func registerFunction(name: String, handler: @escaping ([String: Any]) -> Void) {
        customFunctionHandlers[name] = handler
    }

    /// 延迟设置导航控制器。
    /// 当路由在 DI 阶段初始化后、实际视图创建 NavigationStack 时才获取到 UINavigationController 时使用。
    public func setNavigationController(_ navigationController: UINavigationController?) {
        self.navigationController = navigationController
    }

    // MARK: - Private Helpers

    /// 查找当前最顶层的 presented ViewController，用于无导航控制器时的 present 降级。
    private static func topmostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: {
            $0.activationState == .foregroundActive
        }) as? UIWindowScene else { return nil }
        let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        var top = rootVC
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

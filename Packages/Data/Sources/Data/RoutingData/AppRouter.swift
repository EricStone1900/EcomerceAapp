import Foundation

import RoutingAbstraction

#if canImport(UIKit)
import UIKit

// MARK: - UIKit 实现（iOS 环境）

/// 应用级导航路由器。
///
/// 实现 RouterProtocol，负责：
/// - 将 AppRoute 解析为 UIViewController 并执行 push/present
/// - 维护导航元数据栈，使 goBack 能智能选择 pop 或 dismiss
/// - 应用 RouteBackButtonConfiguration
///
/// 对 UINavigationController / UITabBarController 使用弱引用，避免循环引用。
public final class AppRouter: RouterProtocol {

    private weak var navigationController: UINavigationController?

    private weak var tabBarController: UITabBarController?

    private let factoryRegistry: RouteFactoryRegistry

    /// 导航元数据栈。每次 navigate 记录一条，goBack 时 pop。
    private var navigationMetadata: [NavigationType] = []

    private enum NavigationType {

        case push

        case present
    }

    public init(
        navigationController: UINavigationController?,
        tabBarController: UITabBarController?,
        factoryRegistry: RouteFactoryRegistry
    ) {

        self.navigationController = navigationController
        self.tabBarController = tabBarController
        self.factoryRegistry = factoryRegistry
    }

    // MARK: - RouterProtocol

    public func navigate(to route: AppRoute, configuration: RouteConfiguration) {

        guard let viewController = factoryRegistry.viewController(for: route) else { return }

        applyBarVisibilityIfNeeded(configuration.barVisibility)
        applyTitleIfNeeded(configuration.titleConfiguration, to: viewController)

        let style = configuration.presentationStyle ?? .push

        switch style {
        case .push:
            navigationController?.pushViewController(viewController, animated: true)
            navigationMetadata.append(.push)

        case .present(let modalStyle):
            viewController.modalPresentationStyle = modalStyle.toUIModalPresentationStyle()
            let presenting = navigationController ?? topmostViewController()
            presenting.present(viewController, animated: true)
            navigationMetadata.append(.present)
        }

        applyBackButtonConfiguration(configuration.backButton, to: viewController)
    }

    public func goBack(animated: Bool) {

        guard let lastType = navigationMetadata.popLast() else {

            // 元数据栈为空时退化为 pop（兼容未记录的场景）
            navigationController?.popViewController(animated: animated)
            return
        }

        switch lastType {
        case .push:
            navigationController?.popViewController(animated: animated)

        case .present:
            navigationController?.dismiss(animated: animated)
        }
    }

    // MARK: - Private Helpers

    private func applyBarVisibilityIfNeeded(_ config: RouteBarVisibilityConfiguration?) {

        guard let config = config else { return }
        let animated = config.animated ?? true
        if let hidesNavBar = config.hidesNavigationBar {
            navigationController?.setNavigationBarHidden(hidesNavBar, animated: animated)
        }
    }

    private func applyTitleIfNeeded(_ config: RouteTitleConfiguration?, to viewController: UIViewController) {

        guard let config = config else { return }

        switch config {
        case .text(let text):
            viewController.title = text

        case .attributedText(let attributedText):
            viewController.title = attributedText.string

        case .customTitleView:
            // 自定义 titleView 需要 navigationItem，待阶段 4 基类方案
            break
        }
    }

    private func applyBackButtonConfiguration(_ config: RouteBackButtonConfiguration?, to viewController: UIViewController) {

        guard let config = config else { return }

        switch config {
        case .systemDefault:
            viewController.navigationItem.hidesBackButton = false

        case .hidden:
            viewController.navigationItem.hidesBackButton = true

        case .custom(let title, _):
            viewController.navigationItem.hidesBackButton = false
            if let title {
                let backItem = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
                viewController.navigationItem.backBarButtonItem = backItem
            }
        }
    }

    /// 获取当前最顶层的 ViewController，用于无导航栈时的降级展示。
    private func topmostViewController() -> UIViewController {

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {

            var top = rootVC
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }

        return UIViewController()
    }
}

// MARK: - RouteModalStyle → UIModalPresentationStyle

private extension RouteModalStyle {

    func toUIModalPresentationStyle() -> UIModalPresentationStyle {

        switch self {
        case .fullScreen:  return .fullScreen
        case .pageSheet:   return .pageSheet
        case .formSheet:   return .formSheet
        case .automatic:   return .automatic
        }
    }
}

#else

// MARK: - 空实现（macOS/Linux 编译环境）

/// 空路由器，用于非 iOS 环境编译。
public final class AppRouter: RouterProtocol {

    private let factoryRegistry: RouteFactoryRegistry

    public init(
        navigationController: Any? = nil,
        tabBarController: Any? = nil,
        factoryRegistry: RouteFactoryRegistry
    ) {

        self.factoryRegistry = factoryRegistry
    }

    public func navigate(to route: AppRoute, configuration: RouteConfiguration) {

        // 非 iOS 环境为空操作
    }

    public func goBack(animated: Bool) {

        // 非 iOS 环境为空操作
    }
}

#endif

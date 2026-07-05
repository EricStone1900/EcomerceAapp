import Foundation

import WebContainerAbstraction
import DIAbstraction

extension DIContainer {

    @MainActor
    public static func registerWebContainerData() {

        let initialRules: [WebBridgeRule] = [
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "navigate",
                target: "productDetail",
                nativeAction: .pushRoute(route: "productDetail", params: [:]),
                priority: 10
            ),
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "openCamera",
                target: nil,
                nativeAction: .openCamera,
                priority: 5
            ),
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "dismiss",
                target: nil,
                nativeAction: .dismiss,
                priority: 5
            ),
            // WebTest Tab 测试规则
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "navigate",
                target: "productList",
                nativeAction: .pushRoute(route: "productList", params: [:]),
                priority: 10
            ),
            // 通配规则：未知 route 名称走 routeFactory 尝试创建，创建失败由 router 弹警告
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "navigate",
                target: nil,
                nativeAction: .pushRoute(route: "", params: [:]),
                priority: 1
            ),
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "presentSheet",
                target: "webTestNativeScreen",
                nativeAction: .presentSheet(route: "webTestNativeScreen", params: [:]),
                priority: 10
            ),
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "shareContent",
                target: nil,
                nativeAction: .shareContent(""),
                priority: 5
            ),
            WebBridgeRule(
                handlerName: "nativeBridge",
                action: "showAlert",
                target: nil,
                nativeAction: .showAlert(title: "", message: ""),
                priority: 5
            ),
        ]

        DIContainer.shared.register(WebBridgeRuleRepositoryProtocol.self) { _ in
            WebBridgeRuleRepositoryImpl(initialRules: initialRules)
        }.inObjectScope(.container)

        DIContainer.shared.register(WebContentRepositoryProtocol.self) { _ in
            WebContentRepositoryImpl()
        }
    }
}

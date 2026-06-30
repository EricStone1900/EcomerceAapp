import Foundation

/// 描述一条 Web → Native 映射规则。
public struct WebBridgeRule {
    public let handlerName: String
    public let action: String
    public let target: String?
    public let nativeAction: NativeBridgeAction
    public let priority: Int

    public init(
        handlerName: String,
        action: String,
        target: String?,
        nativeAction: NativeBridgeAction,
        priority: Int
    ) {
        self.handlerName = handlerName
        self.action = action
        self.target = target
        self.nativeAction = nativeAction
        self.priority = priority
    }
}

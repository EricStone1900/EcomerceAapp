import Foundation

/// JS 下发的原始消息经解析后的标准结构。
public struct WebBridgeCommand {
    public let action: String
    public let target: String?
    public let params: [String: Any]

    public init(action: String, target: String?, params: [String: Any]) {
        self.action = action
        self.target = target
        self.params = params
    }
}

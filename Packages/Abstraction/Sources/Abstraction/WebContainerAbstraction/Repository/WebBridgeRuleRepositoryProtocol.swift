import Foundation
import RxSwift

public protocol WebBridgeRuleRepositoryProtocol {
    func fetchRules() -> Observable<[WebBridgeRule]>
    func registerRule(_ rule: WebBridgeRule)
    func clearRules()
}

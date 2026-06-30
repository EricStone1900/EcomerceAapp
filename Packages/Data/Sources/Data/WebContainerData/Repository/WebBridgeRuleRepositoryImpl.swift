import Foundation
import RxSwift

import WebContainerAbstraction

public final class WebBridgeRuleRepositoryImpl: WebBridgeRuleRepositoryProtocol, @unchecked Sendable {
    private var rules: [WebBridgeRule] = []
    private let queue = DispatchQueue(label: "com.app.webbridge.rules", attributes: .concurrent)

    public init(initialRules: [WebBridgeRule] = []) {
        self.rules = initialRules
    }

    public func fetchRules() -> Observable<[WebBridgeRule]> {
        Observable.create { [weak self] observer in
            self?.queue.sync {
                observer.onNext(self?.rules ?? [])
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }

    public func registerRule(_ rule: WebBridgeRule) {
        queue.async(flags: .barrier) { self.rules.append(rule) }
    }

    public func clearRules() {
        queue.async(flags: .barrier) { self.rules.removeAll() }
    }
}

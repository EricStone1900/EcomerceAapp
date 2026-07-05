import Foundation
import RxSwift

import WebContainerAbstraction

public final class ProcessBridgeCommandUseCase: ProcessBridgeCommandUseCaseProtocol {
    private let ruleRepository: WebBridgeRuleRepositoryProtocol

    public init(ruleRepository: WebBridgeRuleRepositoryProtocol) {
        self.ruleRepository = ruleRepository
    }

    public func execute(command: WebBridgeCommand) -> Observable<NativeBridgeAction> {
        ruleRepository.fetchRules().map { rules in
            let sorted = rules.sorted { $0.priority > $1.priority }

            // 1. 精确匹配（action + target）
            if let exact = sorted.first(where: {
                $0.action == command.action && $0.target == command.target
            }) { return self.mergeParams(rule: exact, command: command) }

            // 2. 通配匹配（action，target == nil）
            if let wildcard = sorted.first(where: {
                $0.action == command.action && $0.target == nil
            }) { return self.mergeParams(rule: wildcard, command: command) }

            // 3. 无匹配
            return .none
        }
    }

    /// 将运行时 `command.params` 合并进规则匹配的 `NativeBridgeAction`，
    /// 确保动态参数（如 productId）能正确传递，而非使用规则的静态占位参数。
    /// 通配规则（rule.target == nil）时使用 command.target 作为实际路由名。
    private func mergeParams(rule: WebBridgeRule, command: WebBridgeCommand) -> NativeBridgeAction {
        switch rule.nativeAction {
        case .pushRoute(let route, _):
            let actualRoute = rule.target == nil ? (command.target ?? route) : route
            return .pushRoute(route: actualRoute, params: command.params)
        case .presentSheet(let route, _):
            let actualRoute = rule.target == nil ? (command.target ?? route) : route
            return .presentSheet(route: actualRoute, params: command.params)
        case .callFunction(let name, _):
            return .callFunction(name: name, params: command.params)
        default:
            return rule.nativeAction
        }
    }
}

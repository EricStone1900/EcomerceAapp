#if canImport(UIKit)
import SwiftUI

import RoutingAbstraction
import AnalyticsAbstraction
import DIAbstraction

/// UIHostingController 基类，自动处理：
/// 1. 页面停留时长埋点（viewWillAppear → viewWillDisappear）
///
/// 业务方无需编写任何额外代码即可获得自动埋点能力。
/// 所有通过路由框架创建的页面应使用此类替代 UIHostingController。
open class BaseHostingController<Content: View>: UIHostingController<Content> {

    // MARK: - Analytics

    /// 页面进入时间戳，在 viewWillAppear 中记录
    private var entryTimestamp: Date?

    /// 页面兜底标识符（当未实现 PageLifecycleTrackable 时使用）
    private var pageIdentifier: String?

    /// 设置页面标识符（用于埋点降级兜底）。
    /// 当页面未实现 PageLifecycleTrackable 协议时，使用此值作为 analyticsPageIdentifier。
    /// - Parameter identifier: 页面唯一标识符（如 "product_detail"、"cart_list"）
    public func setPageIdentifier(_ identifier: String) {

        pageIdentifier = identifier
    }

    // MARK: - Lifecycle

    open override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
        entryTimestamp = Date()
    }

    open override func viewWillDisappear(_ animated: Bool) {

        super.viewWillDisappear(animated)
        trackPageLifecycle()
    }

    // MARK: - Private

    /// 计算页面停留时长并发送埋点事件。
    /// - 若 self 实现了 PageLifecycleTrackable，使用其 analyticsPageIdentifier
    /// - 否则使用 pageIdentifier（兜底值）
    /// - 均不存在时为 "unknown_page"
    private func trackPageLifecycle() {

        guard let entryTimestamp else { return }
        let duration = Date().timeIntervalSince(entryTimestamp)

        let identifier: String = {
            if let trackable = self as? PageLifecycleTrackable {
                return trackable.analyticsPageIdentifier
            }
            return pageIdentifier ?? "unknown_page"
        }()

        let extraParams: [String: Any]? = (self as? PageLifecycleTrackable)?.analyticsExtraParameters

        let useCase = DIContainer.shared.resolve(TrackPageLifecycleUseCaseProtocol.self)
        useCase?.start(pageIdentifier: identifier, duration: duration, extraParameters: extraParams)
    }
}
#endif

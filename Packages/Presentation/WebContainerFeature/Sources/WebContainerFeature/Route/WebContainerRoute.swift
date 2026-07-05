import Foundation

import RoutingAbstraction

/// WebContainerFeature 的路由定义。
public enum WebContainerRoute: AppRoute, Sendable {

    /// WebTest 入口页（加载本地测试 HTML）
    case webTestEntry

    /// 原生探针页（验证 Web → Native 跳转链路）
    case webTestNativeProbe
}

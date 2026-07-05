import Foundation

/// 模态展示样式。
/// 对应 iOS UIModalPresentationStyle 的抽象映射。
public enum RouteModalStyle {

    /// 全屏覆盖（对应 UIModalPresentationStyle.fullScreen）
    case fullScreen

    /// 页面表单（对应 UIModalPresentationStyle.pageSheet）
    case pageSheet

    /// 小表单卡片（对应 UIModalPresentationStyle.formSheet）
    case formSheet

    /// 系统自动选择（对应 UIModalPresentationStyle.automatic）
    case automatic
}

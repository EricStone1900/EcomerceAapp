import SwiftUI

import DesignSystem

/// ModuleTest 功能入口列表页。
///
/// 展示各功能组件的调用入口，后续可扩展为导航到具体演示页面。
public struct ModuleTestView: View {

    private let items: [ModuleTestItem] = [
        ModuleTestItem(title: "推送通知测试", subtitle: "测试本地推送功能"),
        ModuleTestItem(title: "文件下载测试", subtitle: "测试文件下载流程"),
        ModuleTestItem(title: "扫码功能测试", subtitle: "测试摄像头扫码"),
        ModuleTestItem(title: "定位服务测试", subtitle: "测试定位权限与获取"),
        ModuleTestItem(title: "网络状态测试", subtitle: "测试网络连通性"),
    ]

    public init() {}

    public var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.appBody)
                Text(item.subtitle)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
            .designPadding(.vertical, .s)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Item Model

private struct ModuleTestItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

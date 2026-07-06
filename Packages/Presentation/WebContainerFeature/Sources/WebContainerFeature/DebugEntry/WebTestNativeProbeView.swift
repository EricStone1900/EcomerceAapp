import SwiftUI

import DesignSystem

/// WebTest 原生探针页。
/// 验证从 WebTest HTML 页面跳转到原生页面的链路畅通。
public struct WebTestNativeProbeView: View {
    private let timestamp: String

    public init() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.timestamp = formatter.string(from: Date())
    }

    public var body: some View {
        VStack(spacing: .spacingXl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.appSuccess)

            Text("✅ 已从 WebTest 成功跳转")
                .font(.appTitle2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            VStack(spacing: .spacingS) {
                Text("跳转时间戳")
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)

                Text(timestamp)
                    .foregroundColor(.appTextPrimary)
            }
            .designPadding(.l)
            .background(
                // TODO: 替换为 surface 色值
                Color(.systemGray6)
            )
            .designCornerRadius(.large)

            Text("每次跳转都会生成新的时间戳，验证原生路由链路畅通")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .designPadding(.horizontal, .l)

            Spacer()
        }
        .designPadding(.l)
        .navigationTitle("探针页")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            WebTestNativeProbeView()
        }
    } else {
        // Fallback on earlier versions
    }
}

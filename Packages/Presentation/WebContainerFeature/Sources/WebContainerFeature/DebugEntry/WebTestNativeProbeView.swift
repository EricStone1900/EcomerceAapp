import SwiftUI

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
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("✅ 已从 WebTest 成功跳转")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text("跳转时间戳")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(timestamp)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )

            Text("每次跳转都会生成新的时间戳，验证原生路由链路畅通")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
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

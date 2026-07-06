import SwiftUI

import DesignSystem

/// DesignSystem 令牌预览页。
///
/// 展示所有颜色、字体、间距、圆角、阴影的视觉效果，
/// 同时也是令牌正确用法的示范代码。
///
/// 使用方式：在任意 NavigationStack 中 push 到该页面即可。
struct DesignSystemPreview: View {
    var body: some View {
        List {
            // MARK: - 颜色预览

            Section("Colors") {
                ColorRow(name: "primary", color: .appPrimary)
                ColorRow(name: "secondary", color: .appSecondary)
                ColorRow(name: "background", color: .appBackground)
                ColorRow(name: "textPrimary", color: .appTextPrimary)
                ColorRow(name: "textSecondary", color: .appTextSecondary)
                ColorRow(name: "success", color: .appSuccess)
                ColorRow(name: "warning", color: .appWarning)
                ColorRow(name: "error", color: .appError)
            }

            // MARK: - 字体预览

            Section("Typography") {
                Text("largeTitle (34 Bold)").font(.appLargeTitle)
                Text("title (28 Regular)").font(.appTitle)
                Text("title2 (22 Regular)").font(.appTitle2)
                Text("headline (17 Semibold)").font(.appHeadline)
                Text("subheadline (15 Regular)").font(.appSubheadline)
                Text("body (17 Regular)").font(.appBody)
                Text("callout (16 Regular)").font(.appCallout)
                Text("caption (12 Regular)").font(.appCaption)
            }

            // MARK: - 间距预览

            Section("Spacing") {
                SpacingRow(label: "xs (4pt)", value: .spacingXs)
                SpacingRow(label: "s (8pt)", value: .spacingS)
                SpacingRow(label: "m (12pt)", value: .spacingM)
                SpacingRow(label: "l (16pt)", value: .spacingL)
                SpacingRow(label: "xl (24pt)", value: .spacingXl)
                SpacingRow(label: "xxl (32pt)", value: .spacingXxl)
            }

            // MARK: - 圆角预览

            Section("Corner Radius") {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.appSecondary).frame(height: 40)
                    .designCornerRadius(.small)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appSecondary).frame(height: 40)
                    .designCornerRadius(.medium)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appSecondary).frame(height: 40)
                    .designCornerRadius(.large)
                Text("Pill Shape").padding().frame(maxWidth: .infinity)
                    .background(Color.appPrimary).foregroundColor(.white)
                    .designCornerRadius(.pill)
            }

            // MARK: - 阴影预览

            Section("Shadow") {
                Text("Card Shadow").padding().frame(maxWidth: .infinity)
                    .background(Color.appBackground)
                    .designCornerRadius(.medium)
                    .designShadow(.card)
                Text("Elevated Shadow").padding().frame(maxWidth: .infinity)
                    .background(Color.appBackground)
                    .designCornerRadius(.medium)
                    .designShadow(.elevated)
            }
        }
        .navigationTitle("DesignSystem Preview")
    }
}

// MARK: - Helper Views

private struct ColorRow: View {
    let name: String
    let color: Color

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color).frame(width: 44, height: 44)
            Text(name).font(.appBody)
        }
    }
}

private struct SpacingRow: View {
    let label: String
    let value: CGFloat

    var body: some View {
        HStack {
            Text(label).font(.appBody)
            Spacer()
            Rectangle().fill(Color.appPrimary).frame(width: value, height: 8)
                .designCornerRadius(.small)
        }
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            DesignSystemPreview()
        }
    } else {
        // Fallback on earlier versions
    }
}

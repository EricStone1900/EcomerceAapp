# 阶段 5：收尾验证 + 文档更新

> 前置依赖：阶段 1-4（DesignSystem 全部令牌类型 + UIKit 兼容层）已完成
> Feature 视图迁移已在之前的执行中完成，本阶段为收尾验证与文档沉淀

---

## Context

项目已完成 DesignSystem 包的五类令牌建设（颜色/字体/圆角/间距/阴影）和 UIKit 兼容层，Feature 视图已大部分迁移。本阶段的目标：
1. 清理剩余 4 处硬编码值
2. 更新 `docs/architecture.md` 补充 DesignSystem 模块说明
3. 更新 `CLAUDE.md` 加入 DesignSystem 使用约定
4. 创建 Token 预览页面（供设计验收和开发参考）

---

## 已完成的工作（不重复执行）

- 颜色令牌（8 语义色 + Asset Catalog 深色/浅色模式）
- 字体字号令牌（8 档位 + Dynamic Type 缩放）
- 圆角与间距令牌（4 + 6 档位）
- 阴影令牌（card/elevated 两档）
- UIKit 兼容层（UIColor + UIFont 桥接）
- BaseNavigationController 迁移
- Feature 视图 29 处硬编码值替换

---

## 剩余硬编码值清理

### 问题 1：`.font(.system(.body, design: .monospaced))`

**文件**：`WebContainerFeature/.../WebTestNativeProbeView.swift:38`
**替换为**：`.font(.appBody).monospaced()`

### 问题 2：`RoundedRectangle(cornerRadius: 12)`

**文件**：`WebContainerFeature/.../WebTestNativeProbeView.swift:43`
**替换为**：去掉 `RoundedRectangle`，仅保留 `.background(Color.appBackground)` + 已有的 `.designCornerRadius(.large)` 剪辑即可。

### 问题 3：`Color(.systemGray6)`

**文件**：`WebContainerFeature/.../WebTestNativeProbeView.swift:44`
**替换为**：注释标记 `// TODO: 替换为 surface 色值`（无现有精确匹配的语义色，保留不变）

### 问题 4：`.background(.ultraThinMaterial)`

**文件**：`WebContainerFeature/.../WebContainerView.swift:24`
**处理**：Material 效果无 DesignSystem 等价物，保留不变。

---

## 文档更新

### 1. `docs/architecture.md` — 补充 DesignSystem 模块说明

在 Utilities 章节追加：

```markdown
| **Utilities/DesignSystem** | 设计令牌系统 — ColorTokensProviding（8 语义色 + Asset Catalog 深色/浅色模式）、TypographyTokensProviding（8 字号档位 + Dynamic Type）、RadiusTokensProviding（4 圆角档位）、SpacingTokensProviding（6 间距档位，4pt 网格）、ShadowTokensProviding（card/elevated 两档阴影）、UIKit 兼容层（UIColor+DesignSystem、UIFont+DesignSystem） | SwiftUI 内置（无外部依赖） |
```

### 2. `CLAUDE.md` — 加入 DesignSystem 使用约定

在「添加新 Feature」部分之前插入新章节：

```markdown
## DesignSystem 使用规范

所有新增 UI 页面必须使用 DesignSystem 提供的语义化令牌，禁止硬编码具体数值。

### 常用令牌速查

| 类别 | 使用方式 |
|------|---------|
| **颜色** | `.foregroundColor(.appTextPrimary)`、`.background(Color.appBackground)` |
| **字体** | `.font(.appBody)`、`.font(.appHeadline)`、`.font(.appTitle)` |
| **间距** | `VStack(spacing: .spacingM)`、`.designPadding(.l)`、`.designPadding(.horizontal, .m)` |
| **圆角** | `.designCornerRadius(.medium)`、`.designCornerRadius(.large)`、`.designCornerRadius(.pill)` |
| **阴影** | `.designShadow(.elevated)`（按钮、弹窗）、`.designShadow(.card)`（卡片） |

### 可用令牌一览

| 协议 | 槽位 |
|------|------|
| `ColorTokensProviding` | primary / secondary / background / textPrimary / textSecondary / success / warning / error |
| `TypographyTokensProviding` | largeTitle / title / title2 / headline / subheadline / body / callout / caption |
| `RadiusTokensProviding` | small(4) / medium(8) / large(12) / pill(Capsule) |
| `SpacingTokensProviding` | xs(4) / s(8) / m(12) / l(16) / xl(24) / xxl(32) |
| `ShadowTokensProviding` | card / elevated |

### 导入方式

```swift
import DesignSystem

// 然后即可使用
Text("Title").font(.appTitle).foregroundColor(.appTextPrimary)
    .designPadding(.l)
    .designCornerRadius(.medium)
```

### Dynamic Type

字体令牌使用 `UIFontMetrics` 实现了 Dynamic Type 缩放，用户调整系统字体大小时字体自动适配。无需额外处理。
```

---

## Token 预览页面

新增 `Packages/Presentation/WebContainerFeature/Sources/WebContainerFeature/DebugEntry/DesignSystemPreview.swift`，集中展示所有 Token 的视觉效果。

使用 DesignSystem 的快捷 API（非硬编码值），预览页面本身作为令牌正确用法的示范：

```swift
import SwiftUI
import DesignSystem

/// DesignSystem 令牌预览页。
/// 展示所有颜色、字体、间距、圆角、阴影的视觉效果，
/// 同时也是令牌正确用法的示范代码。
struct DesignSystemPreview: View {
    var body: some View {
        List {
            // 颜色预览
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

            // 字体预览
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

            // 间距预览
            Section("Spacing") {
                SpacingRow(label: "xs (4pt)", value: .spacingXs)
                SpacingRow(label: "s (8pt)", value: .spacingS)
                SpacingRow(label: "m (12pt)", value: .spacingM)
                SpacingRow(label: "l (16pt)", value: .spacingL)
                SpacingRow(label: "xl (24pt)", value: .spacingXl)
                SpacingRow(label: "xxl (32pt)", value: .spacingXxl)
            }

            // 圆角预览
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
                Text("Pill Shape").padding().background(Color.appPrimary)
                    .foregroundColor(.white)
                    .designCornerRadius(.pill)
            }

            // 阴影预览
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
```

> 该页面可作为 WebTest 的新路由目标，或单独在预览中查看。

---

## 验收清单

- [ ] 4 处剩余硬编码值完成清理或标记
- [ ] `docs/architecture.md` 包含 DesignSystem 模块说明
- [ ] `CLAUDE.md` 包含 DesignSystem 使用规范速查表
- [ ] DesignSystemPreview 页面可编译通过
- [ ] `swift build` 全部通过

---

## 验证方式

```bash
# 编译验证
swift build

# 查看最终视图文件确认无遗留硬编码
grep -n "\.font(\.\|spacing: [0-9]\|\.padding()$" -r Packages/Presentation --include="*.swift" | grep -v "Tests\|Preview\|\.app\|\.design\|spacing: \.spacing"
```

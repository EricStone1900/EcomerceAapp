# 阶段 2：字体字号规范

> 前置依赖：阶段 1（DesignSystem 包骨架 + 颜色令牌）已完成
> 本阶段在 `Packages/Utilities/DesignSystem/` 包内继续扩展字体字号能力

---

## Context

项目当前所有视图使用 SwiftUI 系统默认字体（`.headline`、`.body`、`.title` 等），不存在字体抽象层。阶段 1 已创建 `DesignSystem` 包的颜色令牌体系（协议 + 默认实现 + Environment 注入），本阶段在同一包内补充字体令牌，提供语义化的字号档位，替代分散在各处的"魔法数字"字号。

---

## 字体使用现状分析

所有 Feature 视图的 `.font(...)` 使用情况：

| 视图 | 使用的字体修饰 |
|------|---------------|
| `ProductListView.swift` | `.headline`（产品名）、`.subheadline`（价格） |
| `ItemDetailView.swift` | `.title`（产品名）、`.body`（描述）、`.callout.bold()`（价格） |
| `BasketView.swift` | `.headline`（产品名）、`.subheadline`（价格）、`.title2`（合计） |
| `LoginView.swift` | 无字体修饰（系统默认） |
| `WebContainerView.swift` | 无字体修饰 |
| `WebTestEntryView.swift` | 无字体修饰 |
| `WebTestNativeProbeView.swift` | `.system(size: 64)`（图标）、`.title2`、`.caption`、`.system(.body, design: .monospaced)`、`.footnote` |
| `BaseNavigationController.swift` | `UIFont.systemFont(ofSize: 17, weight: .semibold)`（导航栏标题）、`UIFont.systemFont(ofSize: 34, weight: .bold)`（大标题） |

**结论**：实际使用的字体槽位为：`largeTitle`、`title`、`title2`、`headline`、`subheadline`、`body`、`callout`、`caption`。

---

## 关键设计决策

1. **支持 Dynamic Type**（需要）：通过 `UIFontMetrics` 实现动态字体缩放。SwiftUI 的 `Font` 没有直接的自定义尺寸 Dynamic Type API，使用 `UIFontMetrics(forTextStyle:).scaledFont(for:)` 桥接到 `Font`，使字体能随系统「字体大小」辅助功能设置自动缩放。
2. **协议与颜色令牌分离**：`TypographyTokensProviding` 是独立协议，不与 `ColorTokensProviding` 合并。`DefaultDesignTheme` 同时遵循两个协议，但 Environment 键分开（`.designTheme` 用于颜色，`.typographyTheme` 用于字体），允许独立换肤。
3. **字体档位**：取 8 个实际被使用的槽位（`largeTitle`/`title`/`title2`/`headline`/`subheadline`/`body`/`callout`/`caption`），省略未被使用的 `footnote`（仅 debug 视图用到，暂不纳入）。
4. **便捷访问**：使用 `Font` 静态属性模式（如 `Font.appTitle`），与阶段 1 的 `Color.appPrimary` 风格一致。
5. **不修改已有视图**：本阶段只新建字体令牌基础设施，不迁移已有视图代码。迁移在后续阶段按需进行。
6. **`Package.swift` 更新**：`macOS` 平台从 `.v10_15` 升级到 `.v11`（macOS Big Sur），因为 `Font.TextStyle.title2`/`title3` 在 macOS 11+ 才可用。

---

## 新增 / 修改文件

### 1. 新增 `Sources/DesignSystem/TypographyTokensProviding.swift`

```swift
import SwiftUI

/// 字体字号令牌协议。
///
/// 定义应用中使用的全部语义字号槽位。
/// 支持 Dynamic Type：使用 relativeTo 让字体随系统字体大小设置自动缩放。
public protocol TypographyTokensProviding: Sendable {

    /// 大标题（34pt Bold）
    var largeTitle: Font { get }

    /// 标题（28pt Regular）
    var title: Font { get }

    /// 二级标题（22pt Regular）
    var title2: Font { get }

    /// 强调文字（17pt Semibold）
    var headline: Font { get }

    /// 辅助文字（15pt Regular）
    var subheadline: Font { get }

    /// 正文（17pt Regular）
    var body: Font { get }

    /// 标注文字（16pt Regular）
    var callout: Font { get }

    /// 说明文字（12pt Regular）
    var caption: Font { get }
}
```

### 2. 修改 `Sources/DesignSystem/DefaultDesignTheme.swift`

在已有颜色实现底部追加字体令牌实现，包含 `UIFontMetrics` 桥接辅助方法：

```swift
// MARK: - TypographyTokensProviding

extension DefaultDesignTheme: TypographyTokensProviding {

    public var largeTitle: Font {
        scaledFont(size: 34, weight: .bold, relativeTo: .largeTitle)
    }

    public var title: Font {
        scaledFont(size: 28, weight: .regular, relativeTo: .title)
    }

    // ... 其余槽位 ...

    /// 创建支持 Dynamic Type 的系统字体。
    private func scaledFont(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) -> Font {
        #if canImport(UIKit)
        let uiFont = UIFont.systemFont(ofSize: size, weight: weight.uiKit)
        let scaledFont = UIFontMetrics(forTextStyle: textStyle.uiKit).scaledFont(for: uiFont)
        return Font(scaledFont as CTFont)
        #else
        return Font.system(size: size, weight: weight, design: .default)
        #endif
    }
}
```

### 3. 新增 `Sources/DesignSystem/Font+DesignSystem.swift`

```swift
import SwiftUI

/// 便捷访问 DesignSystem 字体的 Font 扩展。
///
/// 使用方式：`.font(.appTitle)` 或 `.font(.appHeadline)`
public extension Font {

    static var appLargeTitle: Font { DefaultDesignTheme().largeTitle }
    static var appTitle: Font { DefaultDesignTheme().title }
    static var appTitle2: Font { DefaultDesignTheme().title2 }
    static var appHeadline: Font { DefaultDesignTheme().headline }
    static var appSubheadline: Font { DefaultDesignTheme().subheadline }
    static var appBody: Font { DefaultDesignTheme().body }
    static var appCallout: Font { DefaultDesignTheme().callout }
    static var appCaption: Font { DefaultDesignTheme().caption }
}
```

### 4. 新增 `Sources/DesignSystem/TypographyThemeEnvironmentKey.swift`

```swift
import SwiftUI

// MARK: - EnvironmentKey

private struct TypographyThemeEnvironmentKey: EnvironmentKey {

    static let defaultValue: TypographyTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 字体主题。
    ///
    /// 使用方式：
    /// ```swift
    /// @Environment(\.typographyTheme) var typographyTheme
    /// ```
    var typographyTheme: TypographyTokensProviding {
        get { self[TypographyThemeEnvironmentKey.self] }
        set { self[TypographyThemeEnvironmentKey.self] = newValue }
    }
}
```

> 注：`DefaultDesignTheme` 已是 struct + `Sendable`（通过 `ColorTokensProviding: Sendable`），`TypographyTokensProviding` 也继承 `Sendable`，`EnvironmentKey.defaultValue` 不会触发并发警告。

---

## 修改的文件

- `Packages/Utilities/DesignSystem/Package.swift` — macOS 平台从 `.v10_15` 升级到 `.v11`（因 `.title2`/`.title3` 需要 macOS 11+）

## 无修改的文件

以下文件**不需要**修改：
- `ColorTokensProviding.swift`（协议独立，无需修改）
- `Color+DesignSystem.swift`（颜色扩展独立）
- `DesignThemeEnvironmentKey.swift`（颜色环境键独立）

---

## 验收清单

- [ ] `swift build` 可独立编译通过
- [ ] 8 个字体槽位均使用语义化命名（`largeTitle`/`title`/`title2`/`headline`/`subheadline`/`body`/`callout`/`caption`）
- [ ] `TypographyTokensProviding` 继承 `Sendable`，无并发警告
- [ ] 所有字体使用 `UIFontMetrics` 桥接支持 Dynamic Type，在系统「字体大小」调整时可自动缩放
- [ ] `Font.appTitle` 等便捷访问方式可用
- [ ] `@Environment(\.typographyTheme)` 可在任意 View 中读取当前字体主题
- [ ] 现有视图全程使用系统默认字体 `relative(to:)` 实现，确保零视觉回归

---

## 验证方式

```bash
# 1. 单独编译 DesignSystem 包
cd Packages/Utilities/DesignSystem && swift build

# 2. 验证在 SwiftUI View 中使用
# Text("Hello").font(.appTitle)
# @Environment(\.typographyTheme) var typography
# Text("Hello").font(typography.title)

# 3. 确认 Dynamic Type 在模拟器中缩放
# Settings → Accessibility → Display & Text Size → Larger Text
```

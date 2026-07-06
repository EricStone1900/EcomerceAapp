# 阶段 3：圆角与间距规范

> 前置依赖：阶段 1（颜色令牌）、阶段 2（字体字号令牌）已完成
> 本阶段在 `Packages/Utilities/DesignSystem/` 包内继续扩展圆角与间距能力

---

## Context

项目当前仅有一个硬编码圆角值（`cornerRadius: 12`）和少量间距值（`VStack spacing: 8/10/16/24`，`.padding()` 默认 16pt），散布在各视图中，无统一抽象层。阶段 1、2 已建立颜色和字体令牌体系，本阶段补充圆角与间距令牌，统一卡片、按钮等组件的圆角取值和页面间距规范。

---

## 间距/圆角使用现状分析

| 类别 | 值 | 文件 | 用途 |
|------|-----|------|------|
| cornerRadius | 12 | `WebTestNativeProbeView.swift` | 时间戳卡片背景 |
| VStack spacing | 8 | `WebTestNativeProbeView.swift` | 时间戳内标签堆叠 |
| VStack spacing | 10 | `ItemDetailView.swift` | 产品详情内 VStack |
| VStack spacing | 16 | `LoginView.swift` | 登录页输入框+按钮 |
| VStack spacing | 24 | `WebTestNativeProbeView.swift` | 最外层内容堆叠 |
| .padding() | 16（默认） | 7 处 | 各视图根 VStack/Text |

**结论**：实际使用的间距值为 8、10、12、16、24。10pt 不是 4pt 网格的整数倍，可归并到 8pt 或 12pt。

---

## 关键设计决策

1. **4pt 网格**：采用 4pt 基础网格（xs=4, s=8, m=12, l=16, xl=24, xxl=32），覆盖所有现有使用场景。10pt 间距在迁移到令牌时改用 8pt（s）或 12pt（m），视觉差异极小。
2. **圆角槽位**：定义 `small(4)`/`medium(8)`/`large(12)`/`pill(无限大)` 四个档位，覆盖现有 single 12pt 圆角使用场景，并为后续按钮、卡片预留完整档位。
3. **`pill` 特殊处理**：`pill` 使用 `clipShape(Capsule())` 而非固定数值，确保任意高度的视图都被裁切为胶囊形状。
4. **ViewModifier 模式**：圆角使用 `.designCornerRadius(.medium)` ViewModifier 链式调用，间距使用 `.designPadding(.l)` ViewModifier + 静态属性 `CGFloat.spacingL` 两种方式。
5. **Environment 注入**：新增两个 EnvironmentKey 分别提供圆角和间距主题，与已有颜色/字体环境键并列。
6. **协议模式与已有风格一致**：`RadiusTokensProviding`/`SpacingTokensProviding` 均继承 `Sendable`，由 `DefaultDesignTheme` 一并实现。

---

## 新增 / 修改文件

### 1. 新增 `Sources/DesignSystem/RadiusTokensProviding.swift`

```swift
import SwiftUI

/// 圆角令牌协议。
///
/// 定义应用中使用的全部语义圆角槽位。
public protocol RadiusTokensProviding: Sendable {

    /// 小圆角（4pt）
    var small: CGFloat { get }

    /// 中等圆角（8pt）
    var medium: CGFloat { get }

    /// 大圆角（12pt）
    var large: CGFloat { get }

    /// 胶囊形（使用 Capsule 裁切，不依赖固定数值）
    var pill: CGFloat { get }
}
```

### 2. 新增 `Sources/DesignSystem/SpacingTokensProviding.swift`

```swift
import Foundation

/// 间距令牌协议。
///
/// 定义应用中使用的全部语义间距槽位，采用 4pt 网格。
public protocol SpacingTokensProviding: Sendable {

    /// 极窄间距（4pt）
    var xs: CGFloat { get }

    /// 窄间距（8pt）
    var s: CGFloat { get }

    /// 中间距（12pt）
    var m: CGFloat { get }

    /// 宽间距（16pt）
    var l: CGFloat { get }

    /// 加宽间距（24pt）
    var xl: CGFloat { get }

    /// 极大间距（32pt）
    var xxl: CGFloat { get }
}
```

### 3. 新增 `Sources/DesignSystem/RadiusThemeEnvironmentKey.swift`

```swift
import SwiftUI

// MARK: - EnvironmentKey

private struct RadiusThemeEnvironmentKey: EnvironmentKey {

    static let defaultValue: RadiusTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 圆角主题。
    var radiusTheme: RadiusTokensProviding {
        get { self[RadiusThemeEnvironmentKey.self] }
        set { self[RadiusThemeEnvironmentKey.self] = newValue }
    }
}
```

### 4. 新增 `Sources/DesignSystem/SpacingThemeEnvironmentKey.swift`

```swift
import SwiftUI

// MARK: - EnvironmentKey

private struct SpacingThemeEnvironmentKey: EnvironmentKey {

    static let defaultValue: SpacingTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 间距主题。
    var spacingTheme: SpacingTokensProviding {
        get { self[SpacingThemeEnvironmentKey.self] }
        set { self[SpacingThemeEnvironmentKey.self] = newValue }
    }
}
```

### 5. 新增 `Sources/DesignSystem/View+CornerRadius.swift`

```swift
import SwiftUI

/// 语义化圆角修饰器。
///
/// 使用方式：`.designCornerRadius(.medium)`
/// `pill` 使用 Capsule 裁切，其余使用 RoundedRectangle。
public extension View {

    func designCornerRadius(_ radius: DesignCornerRadius) -> some View {
        modifier(DesignCornerRadiusModifier(radius: radius))
    }
}

// MARK: - Public Enum

/// 语义化圆角类型，与 RadiusTokensProviding 的槽位对应。
public enum DesignCornerRadius: CaseIterable, Sendable {

    case small, medium, large, pill
}

// MARK: - Modifier

private struct DesignCornerRadiusModifier: ViewModifier {

    let radius: DesignCornerRadius

    @Environment(\.radiusTheme) private var radiusTheme

    func body(content: Content) -> some View {
        if radius == .pill {
            content.clipShape(Capsule())
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: radius.cornerRadius(from: radiusTheme)))
        }
    }
}

// MARK: - Value Extraction

private extension DesignCornerRadius {

    func cornerRadius(from theme: RadiusTokensProviding) -> CGFloat {
        switch self {
        case .small:  return theme.small
        case .medium: return theme.medium
        case .large:  return theme.large
        case .pill:   return 0 // 不会执行到这里
        }
    }
}
```

### 6. 新增 `Sources/DesignSystem/View+Padding.swift`

```swift
import SwiftUI

/// 语义化间距便捷访问。
///
/// 使用方式：
///   `.designPadding(.l)` — 所有边距
///   `.designPadding(.horizontal, .m)` — 指定边缘
///   `VStack(spacing: .spacingM)` — Stack 间距（使用 CGFloat 扩展）
public extension View {

    func designPadding(_ spacing: DesignSpacing) -> some View {
        padding(spacing.value(from: DefaultDesignTheme()))
    }

    func designPadding(_ edges: Edge.Set, _ spacing: DesignSpacing) -> some View {
        padding(edges, spacing.value(from: DefaultDesignTheme()))
    }
}

// MARK: - Public Enum

/// 语义化间距类型，与 SpacingTokensProviding 的槽位对应。
public enum DesignSpacing: CaseIterable, Sendable {

    case xs, s, m, l, xl, xxl

    public func value(from theme: SpacingTokensProviding) -> CGFloat {
        switch self {
        case .xs:  return theme.xs
        case .s:   return theme.s
        case .m:   return theme.m
        case .l:   return theme.l
        case .xl:  return theme.xl
        case .xxl: return theme.xxl
        }
    }
}

// MARK: - CGFloat Convenience

public extension CGFloat {

    /// 极窄间距（4pt）
    static let spacingXs: CGFloat = DefaultDesignTheme().xs

    /// 窄间距（8pt）
    static let spacingS: CGFloat = DefaultDesignTheme().s

    /// 中间距（12pt）
    static let spacingM: CGFloat = DefaultDesignTheme().m

    /// 宽间距（16pt）
    static let spacingL: CGFloat = DefaultDesignTheme().l

    /// 加宽间距（24pt）
    static let spacingXl: CGFloat = DefaultDesignTheme().xl

    /// 极大间距（32pt）
    static let spacingXxl: CGFloat = DefaultDesignTheme().xxl
}
```

> 注：`CGFloat` 扩展在静态上下文中创建 `DefaultDesignTheme` 实例，由于 `SpacingTokensProviding` 继承 `Sendable` 且实现仅返回常量，无并发问题。

### 7. 修改 `Sources/DesignSystem/DefaultDesignTheme.swift`

在已有 `TypographyTokensProviding` 实现之后追加：

```swift
// MARK: - RadiusTokensProviding

extension DefaultDesignTheme: RadiusTokensProviding {

    public var small: CGFloat { 4 }
    public var medium: CGFloat { 8 }
    public var large: CGFloat { 12 }
    public var pill: CGFloat { .greatestFiniteMagnitude }
}

// MARK: - SpacingTokensProviding

extension DefaultDesignTheme: SpacingTokensProviding {

    public var xs: CGFloat { 4 }
    public var s: CGFloat { 8 }
    public var m: CGFloat { 12 }
    public var l: CGFloat { 16 }
    public var xl: CGFloat { 24 }
    public var xxl: CGFloat { 32 }
}
```

---

## 无修改的文件

以下文件**不需要**修改：
- `Package.swift`（DesignSystem 包依赖不变，使用已有 `CGFloat`/`View` 等系统类型）
- `ColorTokensProviding.swift` / `Color+DesignSystem.swift`
- `TypographyTokensProviding.swift` / `Font+DesignSystem.swift`
- `DesignThemeEnvironmentKey.swift` / `TypographyThemeEnvironmentKey.swift`

---

## 验收清单

- [ ] `swift build` 可独立编译通过
- [ ] 4 个圆角槽位（small/medium/large/pill）均为语义化命名
- [ ] 6 个间距槽位（xs/s/m/l/xl/xxl）均为语义化命名
- [ ] `RadiusTokensProviding` / `SpacingTokensProviding` 均继承 `Sendable`，无并发警告
- [ ] `.designCornerRadius(.medium)` 在视图上可链式调用
- [ ] `.designPadding(.l)` / `.designPadding(.horizontal, .m)` 在视图上可链式调用
- [ ] `CGFloat.spacingM` 等静态属性可用
- [ ] `@Environment(\.radiusTheme)` / `@Environment(\.spacingTheme)` 可在任意 View 中读取当前主题
- [ ] `pill` 使用 `Capsule()` 裁切而非固定数值

---

## 验证方式

```bash
# 1. 单独编译 DesignSystem 包
cd Packages/Utilities/DesignSystem && swift build

# 2. 验证在 SwiftUI View 中使用（后续迁移用）
# Image(systemName: "globe").designCornerRadius(.medium)
# Text("Hello").designPadding(.l)
# VStack(spacing: .spacingM) { ... }
# @Environment(\.radiusTheme) var radiusTheme

# 3. 确认 pill 效果
# Text("Button").padding().background(Color.blue).designCornerRadius(.pill)
```

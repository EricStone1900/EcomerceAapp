# 阶段 1：搭建 DesignSystem 包骨架 + 颜色令牌

> 本阶段可独立执行，是整个 Design System 的地基

---

## Context

当前项目中没有任何颜色抽象层——所有视图依赖 SwiftUI/UIKit 系统默认颜色，不存在主题系统、Color 扩展、或颜色常量。需新建 `DesignSystem` SPM 包，建立语义化的颜色令牌体系，支持深色/浅色模式自动适配。

颜色以**语义名**命名（如 `primary`、`textSecondary`、`error`），不以色值描述命名（不叫 `blue`、`darkGray`）。颜色值放入 Asset Catalog 的 Color Set，同时配置 Any Appearance 与 Dark Appearance，深色模式自动生效。

**依赖前提**：无（独立包，不依赖其他模块）。

---

## 关键设计决策

1. **色值选择**：采用接近 iOS 系统语义色的值，以保证迁移后的视图视觉上无回归。Light 模式使用系统标准色（`#007AFF` 蓝等），Dark 模式使用对应的深色变体（`#0A84FF` 等）。
2. **Assets 目录位置**：放在 `Sources/DesignSystem/Resources/Assets.xcassets/`，通过 SPM `resources: [.process("Resources")]` 声明，代码中通过 `Color(name, bundle: .module)` 加载（`bundle` 参数指向模块资源包）。
3. **协议 + 默认实现**：`ColorTokensProviding` 协议声明颜色槽位，`DefaultDesignTheme` 提供默认实现，引用 Asset Catalog。未来换肤只需实现新协议类型并注入 Environment。
4. **Environment 注入**：通过 `EnvironmentKey` 将当前主题注入 SwiftUI View 树，页面用 `@Environment(\.designTheme)` 取值。
5. **Package.swift 模式**：遵循项目主流 `CaseIterable` 枚举模式（同 Utils/Networking），单 target，无需外部依赖。
6. **Xcode 集成**：包创建后，需要手动在 Xcode 中通过 File → Add Package Dependencies → Add Local 将 `Packages/Utilities/DesignSystem` 添加到项目。后续 Feature 包如需使用 DesignSystem 颜色，需在其 `Package.swift` 中添加 `.package(path: "../Utilities/DesignSystem")` 依赖。
7. **Sendable 与 MainActor**（实施后补充）：`ColorTokensProviding` 需继承 `Sendable`，以解决 `EnvironmentKey.defaultValue` 静态属性的并发安全检查；**不标记** `@MainActor`，因为 `Color` 是值类型且已为 `Sendable`，无需主线程隔离。

---

## 新增文件

### 1. `Packages/Utilities/DesignSystem/Package.swift`

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v15)],
    products: DesignSystemProduct.allCases.map(\.product),
    targets: DesignSystemProduct.allCases.map(\.target)
)

enum DesignSystemProduct: String, CaseIterable {

    case DesignSystem

    // MARK: - Properties

    var path: String { "Sources/\(rawValue)" }

    var product: Product {
        .library(
            name: rawValue,
            targets: [rawValue]
        )
    }

    var target: Target {
        .target(
            name: rawValue,
            resources: [.process("Resources")]
        )
    }
}
```

> 注：无 testsTargets（本阶段不建测试），无外部依赖。

---

### 2. 资源文件：Asset Catalog 与 Color Sets

路径：`Packages/Utilities/DesignSystem/Sources/DesignSystem/Resources/Assets.xcassets/`

#### 2a. `Assets.xcassets/Contents.json`

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

#### 2b~2i. 8 个 Color Set（`Contents.json` 每个文件）

各 Color Set 的 `Contents.json` 结构相同，仅色值不同：

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "XX",
          "green" : "XX",
          "red" : "XX"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "XX",
          "green" : "XX",
          "red" : "XX"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

各 Color Set 的色值（sRGB 0-1 范围）：

| Color Set | Light (R, G, B) | Dark (R, G, B) | Light Hex | Dark Hex |
|-----------|-----------------|----------------|-----------|----------|
| `primary` | 0.000, 0.478, 1.000 | 0.039, 0.518, 1.000 | `#007AFF` | `#0A84FF` |
| `secondary` | 0.557, 0.557, 0.576 | 0.388, 0.388, 0.400 | `#8E8E93` | `#636366` |
| `background` | 1.000, 1.000, 1.000 | 0.000, 0.000, 0.000 | `#FFFFFF` | `#000000` |
| `textPrimary` | 0.000, 0.000, 0.000 | 1.000, 1.000, 1.000 | `#000000` | `#FFFFFF` |
| `textSecondary` | 0.235, 0.235, 0.263 | 0.922, 0.922, 0.961 | `#3C3C43` @ 60% opacity | `#EBEBF5` @ 60% opacity |
| `success` | 0.204, 0.780, 0.349 | 0.188, 0.820, 0.345 | `#34C759` | `#30D158` |
| `warning` | 1.000, 0.584, 0.000 | 1.000, 0.624, 0.039 | `#FF9500` | `#FF9F0A` |
| `error` | 1.000, 0.231, 0.188 | 1.000, 0.271, 0.227 | `#FF3B30` | `#FF453A` |

**文件名对应规则**：
- `primary.colorset/Contents.json`
- `secondary.colorset/Contents.json`
- `background.colorset/Contents.json`
- `textPrimary.colorset/Contents.json`
- `textSecondary.colorset/Contents.json`
- `success.colorset/Contents.json`
- `warning.colorset/Contents.json`
- `error.colorset/Contents.json`

> 注意：`textSecondary` 的 alpha 通道为 `0.600`（对应 60% 不透明度），其他颜色 alpha 为 `1.000`。

---

### 3. `Sources/DesignSystem/ColorTokensProviding.swift`

```swift
import SwiftUI

/// 颜色令牌协议。
///
/// 定义应用中使用的全部语义颜色槽位。
/// 实现此协议可提供不同的主题色板（例如 DefaultDesignTheme）。
@MainActor
public protocol ColorTokensProviding {

    /// 主色调（品牌色）
    var primary: Color { get }

    /// 次要色
    var secondary: Color { get }

    /// 背景色
    var background: Color { get }

    /// 主要文字色
    var textPrimary: Color { get }

    /// 次要文字色
    var textSecondary: Color { get }

    /// 成功/正向语义色
    var success: Color { get }

    /// 警告语义色
    var warning: Color { get }

    /// 错误/负向语义色
    var error: Color { get }
}
```

---

### 4. `Sources/DesignSystem/DefaultDesignTheme.swift`

```swift
import SwiftUI

/// 默认主题实现。
///
/// 从 Asset Catalog 的 Color Set 中读取色值，
/// 深色/浅色模式由 Asset Catalog 自动适配。
@MainActor
public struct DefaultDesignTheme: ColorTokensProviding {

    public init() {}

    public var primary: Color {
        Color("primary", bundle: .module)
    }

    public var secondary: Color {
        Color("secondary", bundle: .module)
    }

    public var background: Color {
        Color("background", bundle: .module)
    }

    public var textPrimary: Color {
        Color("textPrimary", bundle: .module)
    }

    public var textSecondary: Color {
        Color("textSecondary", bundle: .module)
    }

    public var success: Color {
        Color("success", bundle: .module)
    }

    public var warning: Color {
        Color("warning", bundle: .module)
    }

    public var error: Color {
        Color("error", bundle: .module)
    }
}
```

---

### 5. `Sources/DesignSystem/Color+DesignSystem.swift`

```swift
import SwiftUI

/// 便捷访问 DesignSystem 颜色的 Color 扩展。
///
/// 使用方式：`Color.appPrimary`
public extension Color {

    static var appPrimary: Color {
        DefaultDesignTheme().primary
    }

    static var appSecondary: Color {
        DefaultDesignTheme().secondary
    }

    static var appBackground: Color {
        DefaultDesignTheme().background
    }

    static var appTextPrimary: Color {
        DefaultDesignTheme().textPrimary
    }

    static var appTextSecondary: Color {
        DefaultDesignTheme().textSecondary
    }

    static var appSuccess: Color {
        DefaultDesignTheme().success
    }

    static var appWarning: Color {
        DefaultDesignTheme().warning
    }

    static var appError: Color {
        DefaultDesignTheme().error
    }
}
```

---

### 6. `Sources/DesignSystem/DesignThemeEnvironmentKey.swift`

```swift
import SwiftUI

// MARK: - EnvironmentKey

private struct DesignThemeEnvironmentKey: EnvironmentKey {

    @MainActor
    static let defaultValue: ColorTokensProviding = DefaultDesignTheme()
}

// MARK: - EnvironmentValues Extension

public extension EnvironmentValues {

    /// 当前 DesignSystem 主题。
    ///
    /// 使用方式：
    /// ```swift
    /// @Environment(\.designTheme) var designTheme
    /// ```
    var designTheme: ColorTokensProviding {
        get { self[DesignThemeEnvironmentKey.self] }
        set { self[DesignThemeEnvironmentKey.self] = newValue }
    }
}
```

> 注意：由于 `ColorTokensProviding` 标记为 `@MainActor`，`defaultValue` 也需要 `@MainActor`。

---

## 验收清单

- [ ] `swift build` 在包目录下可独立编译通过
- [ ] `xed .` 打开项目后，Xcode 能正常索引并编译包含 DesignSystem 的项目
- [ ] 8 个 Color Set 均已配置浅色/深色两套取值，命名均为语义化命名
- [ ] `ColorTokensProviding` 声明了全部 8 个语义颜色槽位，值类型为 `Color`
- [ ] `DefaultDesignTheme` 实现引用 Asset Catalog Color Set（通过 `Color("name", bundle: .module)`）
- [ ] `Color.appPrimary` 等便捷访问方式可用
- [ ] `@Environment(\.designTheme)` 可在任意 View 中读取当前主题
- [ ] 所有颜色槽位命名均为语义化命名，没有出现 "blue"/"gray1" 这类描述性命名

---

## 验证方式

```bash
# 1. 单独编译 DesignSystem 包
cd Packages/Utilities/DesignSystem && swift build

# 2. 运行 Xcode 项目（确认集成正常）
xed .
# 在 Xcode 中按 ⌘B 编译

# 3. 确认深色/浅色模式切换
# 在模拟器 Settings → Developer → Appearance 切换 Dark/Light
# 或在 Xcode 预览使用 .preferredColorScheme(.dark)
```

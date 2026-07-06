# Stage 1：搭建 DesignSystem 包骨架 + 颜色令牌

## Context

项目目前没有统一的颜色/主题系统。所有 View 都使用系统默认颜色或私有的硬编码色值（`UIColor.label`、`.systemBlue` 等），缺少可维护的语义化颜色体系。

本阶段在 `Packages/Utilities/DesignSystem/` 位置新建独立的 DesignSystem SPM 包，建立颜色令牌体系：通过 Asset Catalog Color Set + 协议抽象 + SwiftUI Environment 注入，实现语义化、可切换、深色模式自动适配的颜色基础设施。

DesignSystem 属于横切基础设施，与 Analytics、Networking、Utils、PresentationCore 同级，位于 `Packages/Utilities/` 下，任何 Feature 包都可以依赖它，它不依赖任何业务包。

## 关键设计决策

1. **传统 Package.swift 模式**：DesignSystem 是单 target 包（只有一个 `DesignSystem` 产物），参照同目录下的 Analytics/PresentationCore 使用显式 target 定义格式，不采用 CaseIterable 枚举模式，保持简洁。

2. **Color Set 放 Assets.xcassets**：所有颜色值在 `.colorset` 中同时配置 Any Appearance（浅色）和 Dark Appearance（深色）两套 sRGB 色值，系统自动根据当前模式切换，不需要代码写 if/else。

3. **语义命名**：颜色槽位以 `primary`、`background`、`textPrimary` 等语义命名，严禁出现 `blue`、`gray1` 等描述性命名。色值引用 iOS 系统标准语义颜色（systemBlue、systemBackground、label 等）的近似值，确保视觉与系统默认一致。

4. **协议抽象**：`ColorTokensProviding` 协议作为颜色提供者的契约，`DefaultDesignTheme` 为默认实现。页面通过协议取值，为后续动态换肤/主题切换预留扩展点。

5. **SwiftUI Environment 注入**：通过 `DesignThemeEnvironmentKey` 将主题注入 View 树，页面通过 `@Environment(\.designTheme)` 按需获取主题色，无需手动传递。

6. **SPM 资源路径**：Asset Catalog 必须放在 `Sources/DesignSystem/` 目录下（而非 `Sources/DesignSystem/Resources/`），因为 SPM `.target` 的默认资源搜索路径是 target 根目录。

## 颜色值定义

以下色值取自 iOS 15 标准语义颜色的 sRGB 分量，分别配置浅色/深色模式：

| Color Set Token | 浅色 (Any) | 深色 (Dark) | 对应系统色 |
|---|---|---|---|
| `primary` | #007AFF | #0A84FF | systemBlue |
| `secondary` | #8E8E93 | #98989E | systemGray |
| `background` | #FFFFFF | #1C1C1E | systemBackground |
| `textPrimary` | #000000 | #FFFFFF | label |
| `textSecondary` | #3C3C43, alpha 0.6 | #EBEBF5, alpha 0.6 | secondaryLabel |
| `success` | #34C759 | #30D158 | systemGreen |
| `warning` | #FF9500 | #FF9F0A | systemOrange |
| `error` | #FF3B30 | #FF453A | systemRed |

> textSecondary 使用带 alpha 的分量定义，模拟 `UIColor.secondaryLabel` 的 60% 不透明度效果。在 Asset Catalog 的 `Contents.json` 中通过 `"components"` 的 `"alpha"` 字段实现。

## 涉及包与依赖关系

```
Utilities/DesignSystem  (新建)
  └── 无外部依赖（仅引用 Foundation/UIKit/SwiftUI 系统框架）

Utilities/Analytics
Utilities/PresentationCore
Utilities/Networking/API
  └── 本阶段不修改，后续按需添加 DesignSystem 依赖
```

## 修改文件

### 1. `MyEcommerce.xcodeproj/project.pbxproj`

Xcode 项目需要以下四处修改：

**a) PBXFileReference 区 — 新增 DesignSystem 包引用**
在 `/* Begin PBXFileReference section */` 中新增：
```
38XXXXXX2EXXXXXX00XXXXXXXX /* DesignSystem */ = {isa = PBXFileReference; lastKnownFileType = wrapper; path = DesignSystem; sourceTree = "<group>"; };
```
> 具体 UUID 由 Xcode 自动生成；手动编辑后打开 Xcode 生成或后续 `xed .` 时自动补全。

**b) PBXGroup 区 — Utilities 组增加 DesignSystem 子节点**
在 `/* Utilities */` group 的 `children` 数组中增加 `38XXXXXX2EXXXXXX00XXXXXXXX /* DesignSystem */`。

**c) XCSwiftPackageProductDependency 区 — 注册 DesignSystem 产品**
在 `/* Begin XCSwiftPackageProductDependency section */` 中新增：
```
38YYYYYY2EYYYYYY00YYYYYYYY /* DesignSystem */ = {
    isa = XCSwiftPackageProductDependency;
    productName = DesignSystem;
};
```

**d) 主 target packageProductDependencies — 加入 DesignSystem**
在 `38E8178A2CB84D6500086B2A /* MyEcommerce */` 的 `packageProductDependencies` 数组中增加 `38YYYYYY2EYYYYYY00YYYYYYYY /* DesignSystem */`。

---

## 新增文件（12 个文件）

### 目录结构

```
Packages/Utilities/DesignSystem/
  Package.swift
  Sources/
    DesignSystem/
      Assets.xcassets/
        Contents.json
        primary.colorset/Contents.json
        secondary.colorset/Contents.json
        background.colorset/Contents.json
        textPrimary.colorset/Contents.json
        textSecondary.colorset/Contents.json
        success.colorset/Contents.json
        warning.colorset/Contents.json
        error.colorset/Contents.json
      ColorTokensProviding.swift
      DefaultDesignTheme.swift
      SwiftUI/
        Color+DesignSystem.swift
        DesignThemeEnvironmentKey.swift
  Tests/
    DesignSystemTests/
      DesignSystemTests.swift
```

### 1. `Packages/Utilities/DesignSystem/Package.swift`

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "DesignSystem",
            targets: ["DesignSystem"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DesignSystem",
            resources: [.process("Assets.xcassets")]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"]
        ),
    ]
)
```

关键点：
- 平台 iOS 15，与项目其他包一致
- 无外部依赖（SwiftUI 为系统框架，Package.swift 无需声明）
- `.process("Assets.xcassets")` 告诉 SPM 将 Asset Catalog 打包进模块 bundle

### 2-9. `Assets.xcassets` 及 8 个 `.colorset`

**`Sources/DesignSystem/Assets.xcassets/Contents.json`**：
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

每个 Color Set 的 `Contents.json` 遵循以下模板，以 `primary` 为例：

**`Sources/DesignSystem/Assets.xcassets/primary.colorset/Contents.json`**：
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "1.000",
          "green" : "0.478",
          "red" : "0.000"
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
          "blue" : "1.000",
          "green" : "0.518",
          "red" : "0.039"
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

各 colorset 色值分量（红色表示 X 轴，绿色表示 Y 轴，蓝色表示 Z 轴，alpha 值在 alpha 分量中）：

| colorset | Light red | Light green | Light blue | Light alpha | Dark red | Dark green | Dark blue | Dark alpha |
|---|---|---|---|---|---|---|---|---|
| primary | 0.000 | 0.478 | 1.000 | 1.0 | 0.039 | 0.518 | 1.000 | 1.0 |
| secondary | 0.557 | 0.557 | 0.576 | 1.0 | 0.596 | 0.596 | 0.620 | 1.0 |
| background | 1.000 | 1.000 | 1.000 | 1.0 | 0.110 | 0.110 | 0.118 | 1.0 |
| textPrimary | 0.000 | 0.000 | 0.000 | 1.0 | 1.000 | 1.000 | 1.000 | 1.0 |
| textSecondary | 0.235 | 0.235 | 0.263 | 0.6 | 0.922 | 0.922 | 0.961 | 0.6 |
| success | 0.204 | 0.780 | 0.349 | 1.0 | 0.188 | 0.820 | 0.345 | 1.0 |
| warning | 1.000 | 0.584 | 0.000 | 1.0 | 1.000 | 0.624 | 0.039 | 1.0 |
| error | 1.000 | 0.231 | 0.188 | 1.0 | 1.000 | 0.271 | 0.227 | 1.0 |

### 10. `Sources/DesignSystem/ColorTokensProviding.swift`

```swift
import SwiftUI

/// 颜色令牌提供协议。
///
/// 遵循此协议的类型提供一组语义化颜色属性，
/// 所有视图应通过此协议取值，不直接引用具体实现类型。
/// 为后续动态换肤/主题切换预留扩展点。
public protocol ColorTokensProviding {
    /// 主要品牌色，用于主按钮、激活态、链接等
    var primary: Color { get }
    /// 次要色，用于次要按钮、辅助元素
    var secondary: Color { get }
    /// 页面背景色
    var background: Color { get }
    /// 主要文本色
    var textPrimary: Color { get }
    /// 次要文本色，用于副标题、说明文字
    var textSecondary: Color { get }
    /// 成功/确认状态色
    var success: Color { get }
    /// 警告状态色
    var warning: Color { get }
    /// 错误/危险状态色
    var error: Color { get }
}
```

### 11. `Sources/DesignSystem/DefaultDesignTheme.swift`

```swift
import SwiftUI

/// 默认 DesignSystem 主题实现。
///
/// 所有颜色引用 `Assets.xcassets` 中定义的 Color Set，
/// 通过 `bundle: .module` 确保 SPM 资源路径正确。
/// 深色/浅色模式由 Asset Catalog 的 Appearance 配置自动切换。
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

### 12. `Sources/DesignSystem/SwiftUI/Color+DesignSystem.swift`

```swift
import SwiftUI

/// Color 便捷静态扩展。
///
/// 提供 `Color.ds.primary` 等便捷访问方式，
/// 避免视图直接引用主题实例。
public extension Color {

    /// DesignSystem 命名空间
    static let ds = DesignSystemColorProvider()
}

/// 通过静态属性暴露 DesignSystem 颜色令牌。
public struct DesignSystemColorProvider {

    public init() {}

    public var primary: Color {
        DefaultDesignTheme().primary
    }

    public var secondary: Color {
        DefaultDesignTheme().secondary
    }

    public var background: Color {
        DefaultDesignTheme().background
    }

    public var textPrimary: Color {
        DefaultDesignTheme().textPrimary
    }

    public var textSecondary: Color {
        DefaultDesignTheme().textSecondary
    }

    public var success: Color {
        DefaultDesignTheme().success
    }

    public var warning: Color {
        DefaultDesignTheme().warning
    }

    public var error: Color {
        DefaultDesignTheme().error
    }
}
```

设计理由：
- `Color.ds.primary` 比 `Theme().primary` 更语义化、更 SwiftUI 原生
- `Color.ds` 使用 `static let`，所有属性在首次访问时懒加载 `DefaultDesignTheme()`，无需单例
- `DesignSystemColorProvider` 为值类型 struct，无额外开销

### 13. `Sources/DesignSystem/SwiftUI/DesignThemeEnvironmentKey.swift`

```swift
import SwiftUI

/// EnvironmentKey，用于将当前主题注入 SwiftUI 视图树。
private struct DesignThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ColorTokensProviding = DefaultDesignTheme()
}

public extension EnvironmentValues {

    /// 当前 DesignSystem 颜色主题。
    ///
    /// 用法：
    /// ```swift
    /// @Environment(\.designTheme) private var theme
    ///
    /// var body: some View {
    ///     Text("Hello")
    ///         .foregroundColor(theme.textPrimary)
    /// }
    /// ```
    var designTheme: ColorTokensProviding {
        get { self[DesignThemeEnvironmentKey.self] }
        set { self[DesignThemeEnvironmentKey.self] = newValue }
    }
}
```

### 14. `Tests/DesignSystemTests/DesignSystemTests.swift`

```swift
import Testing
@testable import DesignSystem

@Test("DefaultDesignTheme provides non-transparent colors")
func testDefaultThemeColorsAreOpaque() {
    let theme = DefaultDesignTheme()

    // 主要色值应非 nil（资源已正确加载）
    #expect(theme.primary != .clear)
    #expect(theme.secondary != .clear)
    #expect(theme.background != .clear)
    #expect(theme.textPrimary != .clear)
    #expect(theme.textSecondary != .clear)
    #expect(theme.success != .clear)
    #expect(theme.warning != .clear)
    #expect(theme.error != .clear)
}

@Test("DesignSystemColorProvider produces same colors as DefaultDesignTheme")
func testStaticProviderMatchesTheme() {
    let theme = DefaultDesignTheme()

    // 注意：SwiftUI Color 的相等性基于 identity，不是 RGBA 值
    // 此测试验证 Color.ds 能正常解析且不为 clear
    #expect(Color.ds.primary != .clear)
    #expect(Color.ds.background != .clear)
    #expect(Color.ds.textPrimary != .clear)
    #expect(Color.ds.textSecondary != .clear)
}

@Test("DesignThemeEnvironmentKey has default value")
func testEnvironmentKeyDefault() {
    #expect(DesignThemeEnvironmentKey.defaultValue is DefaultDesignTheme)
}
```

## 执行顺序

1. `Package.swift` — 创建 DesignSystem 包清单，声明 assets 资源
2. `Assets.xcassets/Contents.json` — Asset Catalog 根目录描述文件
3. 8 个 `.colorset/Contents.json` — 逐一创建各语义色槽，配置浅色/深色分量
4. `ColorTokensProviding.swift` — 颜色协议定义
5. `DefaultDesignTheme.swift` — 默认主题实现
6. `Color+DesignSystem.swift` — Color 便捷静态扩展
7. `DesignThemeEnvironmentKey.swift` — SwiftUI Environment 注入
8. `DesignSystemTests.swift` — 基础编译/加载验证测试
9. 验证：`cd Packages/Utilities/DesignSystem && swift build` 编译通过
10. 验证：`cd Packages/Utilities/DesignSystem && swift test` 测试通过
11. 更新 `MyEcommerce.xcodeproj/project.pbxproj` — 在 Utilities 组、FileReference、产品依赖中注册 DesignSystem
12. 打开 Xcode 验证项目能正确解析包依赖（`xed .`）
13. **验收验证**：选一个已有页面替换硬编码颜色（如更新 `BaseNavigationController` 中的 `tintColor = .systemBlue` 为 `UIColor(Color.ds.primary)`），检查深色/浅色模式切换是否自动适配

## 验收清单

- [ ] `cd Packages/Utilities/DesignSystem && swift build` 编译通过
- [ ] `cd Packages/Utilities/DesignSystem && swift test` 全部通过（至少 3 个测试）
- [ ] `xed .` 打开后 Xcode 能正确解析 DesignSystem 包依赖
- [ ] 8 个 Color Set（primary, secondary, background, textPrimary, textSecondary, success, warning, error）均配置了 Any + Dark 两套 Appearance
- [ ] 所有 Color Set 使用语义化命名，无 `blue`/`gray1`/`redColor` 等描述性命名
- [ ] `Color.ds.primary` 等便捷访问方式正常工作
- [ ] `@Environment(\.designTheme)` 注入后返回的 theme 类型为 `DefaultDesignTheme`
- [ ] 至少一个已有页面（如 `BaseNavigationController`）替换了硬编码颜色为 `Color.ds.xxx`，运行后浅色/深色模式切换自动响应且视觉效果无回归
- [ ] 计划文档同步更新至 `docs/specs/stage1_color_tokens.md`（若已有内容更完整则覆盖更新）

## 后续迁移策略（本阶段不执行，仅作计划参考）

- 各 Feature 包（ProductsFeature、BasketFeature、LoginFeature 等）后续如要使用 DesignSystem 颜色，需在其 `Package.swift` 的 `dependencies` 中增加 `.package(path: "../Utilities/DesignSystem")`，并在 `dependencies` 计算属性中添加 `.product(name: "DesignSystem", package: "DesignSystem")`
- PresentationCore 可增加 DesignSystem 依赖后用 `Color.ds.xxx` 替换 `UIColor.label` / `.systemBlue` 等硬编码
- 阶段 2 将在 DesignSystem 基础上补充字体字号规范（TypographyTokensProviding）

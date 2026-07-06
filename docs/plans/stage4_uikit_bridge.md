# 阶段 4（可选部分跳过）：UIKit 兼容层

> 前置依赖：阶段 1-3（颜色、字体、圆角/间距令牌）已完成
> 本阶段在 `DesignSystem` 包中补充 UIKit 兼容层，并迁移 `PresentationCore` 中的硬编码 UIKit 值

---

## Context

项目工程是 UIKit 导航容器（`UINavigationController`）承载 SwiftUI 内容的混合结构，已在 `PresentationCore` 中存在 `BaseNavigationController`（UINavigationController 子类），其中包含 7 处硬编码的 UIKit 颜色/字体值。阶段 1-3 已建立完整的 SwiftUI 侧设计令牌体系，但 UIKit 侧仍使用分散的硬编码系统值。

同时，调研发现**项目中没有任何阴影（shadow）使用**——SwiftUI 和 UIKit 代码中均无 `.shadow()`、`layer.shadow*`、`NSShadow` 等——因此跳过阴影规范部分。

---

## UIKit 硬编码现状（需迁移的目标）

BaseNavigationController.swift（`PresentationCore` 包）：

| 行 | 当前硬编码值 | 应替换为 DesignSystem 令牌 |
|------|-------------|--------------------------|
| 33 | `.font: UIFont.systemFont(ofSize: 17, weight: .semibold)` | `UIFont.appHeadline` |
| 34 | `.foregroundColor: UIColor.label` | `UIColor.appTextPrimary` |
| 37 | `.font: UIFont.systemFont(ofSize: 34, weight: .bold)` | `UIFont.appLargeTitle` |
| 38 | `.foregroundColor: UIColor.label` | `UIColor.appTextPrimary` |
| 51 | `navigationBar.tintColor = .systemBlue` | `UIColor.appPrimary` |

其他 UIKit 代码（`AppRouter.swift`、`RouteTitleConfiguration.swift` 等）不包含硬编码颜色/字体，无需修改。

---

## 关键设计决策

1. **跳过阴影规范**：项目中无任何阴影使用，不创建阴影令牌。后续如需可补充。
2. **UIColor 桥接**：通过 `UIColor(named:in:compatibleWith:)` 直接引用 DesignSystem 的 Asset Catalog Color Set，与 SwiftUI 侧 `Color("name", bundle: .module)` 读取同一份资源，确保两侧视觉一致。
3. **UIFont 桥接**：通过 `UIFontMetrics` 实现 Dynamic Type 缩放——与阶段 2 的 `DefaultDesignTheme.scaledFont` 同模式，但返回 `UIFont` 类型。
4. **PresentationCore 依赖 DesignSystem**：`PresentationCore` 需要在其 `Package.swift` 中新增 DesignSystem 为本地依赖。
5. **作用域限制**：UIKit 扩展文件使用 `#if canImport(UIKit)` 包裹，确保仅 iOS 编译，macOS 编译时跳过。

---

## 新增 / 修改文件

### 1. 新增 `Sources/DesignSystem/UIColor+DesignSystem.swift`

```swift
#if canImport(UIKit)
import UIKit

/// 便捷访问 DesignSystem 颜色的 UIColor 扩展。
///
/// 使用方式：`UIColor.appPrimary`
/// 与 SwiftUI 的 `Color.appPrimary` 读取同一份 Asset Catalog Color Set，
/// 深色/浅色模式由 Asset Catalog 自动适配。
public extension UIColor {

    static var appPrimary: UIColor {
        UIColor(named: "primary", in: .module, compatibleWith: nil)!
    }

    static var appSecondary: UIColor {
        UIColor(named: "secondary", in: .module, compatibleWith: nil)!
    }

    static var appBackground: UIColor {
        UIColor(named: "background", in: .module, compatibleWith: nil)!
    }

    static var appTextPrimary: UIColor {
        UIColor(named: "textPrimary", in: .module, compatibleWith: nil)!
    }

    static var appTextSecondary: UIColor {
        UIColor(named: "textSecondary", in: .module, compatibleWith: nil)!
    }

    static var appSuccess: UIColor {
        UIColor(named: "success", in: .module, compatibleWith: nil)!
    }

    static var appWarning: UIColor {
        UIColor(named: "warning", in: .module, compatibleWith: nil)!
    }

    static var appError: UIColor {
        UIColor(named: "error", in: .module, compatibleWith: nil)!
    }
}
#endif
```

### 2. 新增 `Sources/DesignSystem/UIFont+DesignSystem.swift`

```swift
#if canImport(UIKit)
import UIKit

/// 便捷访问 DesignSystem 字体的 UIFont 扩展。
///
/// 使用方式：`UIFont.appHeadline`、`UIFont.appLargeTitle`
/// 支持 Dynamic Type，通过 UIFontMetrics 实现无障碍缩放。
public extension UIFont {

    static var appLargeTitle: UIFont {
        scaledSystemFont(size: 34, weight: .bold, textStyle: .largeTitle)
    }

    static var appTitle: UIFont {
        scaledSystemFont(size: 28, weight: .regular, textStyle: .title1)
    }

    static var appTitle2: UIFont {
        scaledSystemFont(size: 22, weight: .regular, textStyle: .title2)
    }

    static var appHeadline: UIFont {
        scaledSystemFont(size: 17, weight: .semibold, textStyle: .headline)
    }

    static var appSubheadline: UIFont {
        scaledSystemFont(size: 15, weight: .regular, textStyle: .subheadline)
    }

    static var appBody: UIFont {
        scaledSystemFont(size: 17, weight: .regular, textStyle: .body)
    }

    static var appCallout: UIFont {
        scaledSystemFont(size: 16, weight: .regular, textStyle: .callout)
    }

    static var appCaption: UIFont {
        scaledSystemFont(size: 12, weight: .regular, textStyle: .caption1)
    }

    // MARK: - Helper

    private static func scaledSystemFont(size: CGFloat, weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }
}
#endif
```

> 注：槽位与 TypographyTokensProviding 的 8 个字体档位一一对应，`caption` 使用 `UIFont.TextStyle.caption1`（12pt）。

### 3. 修改 `Packages/Utilities/PresentationCore/Package.swift`

添加 DesignSystem 为依赖：

```swift
dependencies: [
    .package(path: "../../Abstraction"),
    .package(path: "../DesignSystem"),
    .package(url: "https://github.com/Swinject/Swinject", .upToNextMajor(from: "2.9.1")),
],
```

在 target dependencies 中添加 DesignSystem：

```swift
.target(
    name: "PresentationCore",
    dependencies: [
        .product(name: "RoutingAbstraction", package: "Abstraction"),
        .product(name: "AnalyticsAbstraction", package: "Abstraction"),
        .product(name: "DIAbstraction", package: "Abstraction"),
        .product(name: "DesignSystem", package: "DesignSystem"),
        .product(name: "Swinject", package: "Swinject"),
    ]
),
```

### 4. 修改 `Sources/PresentationCore/BaseNavigationController.swift`

```swift
import DesignSystem  // 在文件顶部导入

// 替换 configureAppearance() 中的硬编码值：

// 之前：
// .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
// .foregroundColor: UIColor.label,

// 之后：
appearance.titleTextAttributes = [
    .font: UIFont.appHeadline,
    .foregroundColor: UIColor.appTextPrimary,
]

// 之前：
// .font: UIFont.systemFont(ofSize: 34, weight: .bold),
// .foregroundColor: UIColor.label,

// 之后：
appearance.largeTitleTextAttributes = [
    .font: UIFont.appLargeTitle,
    .foregroundColor: UIColor.appTextPrimary,
]

// 之前：
// navigationBar.tintColor = .systemBlue

// 之后：
navigationBar.tintColor = UIColor.appPrimary
```

完整文件修改（仅 `configureAppearance()` 方法内的 5 处替换）：

```swift
open func configureAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()

    appearance.titleTextAttributes = [
        .font: UIFont.appHeadline,
        .foregroundColor: UIColor.appTextPrimary,
    ]
    appearance.largeTitleTextAttributes = [
        .font: UIFont.appLargeTitle,
        .foregroundColor: UIColor.appTextPrimary,
    ]

    let backImage = UIImage(systemName: "chevron.left")
    appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)

    navigationBar.standardAppearance = appearance
    navigationBar.scrollEdgeAppearance = appearance
    navigationBar.compactAppearance = appearance

    navigationBar.tintColor = UIColor.appPrimary
}
```

---

## 无修改的文件

以下文件**不需要**修改：
- `DefaultDesignTheme.swift`（已有 UIKit 桥接辅助方法，无需补充）
- 所有 Color/Spacing/Radius 协议及 SwiftUI 扩展文件
- `AppRouter.swift`（无硬编码颜色/字体）
- `MyEcommerceApp.swift`（无 UIKit 代码）

---

## 验收清单

- [ ] `swift build` 在 DesignSystem 包目录下可独立编译通过
- [ ] `swift build` 在 PresentationCore 包目录下可编译通过
- [ ] 8 个 `UIColor.app*` 便捷访问方法可用
- [ ] 8 个 `UIFont.app*` 便捷访问方法可用
- [ ] `BaseNavigationController` 中的 5 处硬编码值全部替换为 DesignSystem 令牌
- [ ] UIKit 侧（导航栏）的颜色/字体来源于 Asset Catalog，与 SwiftUI 侧视觉一致
- [ ] UIColor/UIFont 扩展通过 `#if canImport(UIKit)` 条件编译

---

## 验证方式

```bash
# 1. 单独编译 DesignSystem 包
cd Packages/Utilities/DesignSystem && swift build

# 2. 单独编译 PresentationCore 包（验证 DesignSystem 依赖集成正确）
cd Packages/Utilities/PresentationCore && swift build

# 3. 整体 Xcode 编译
xed .
# ⌘B 编译通过

# 4. 确认导航栏颜色与 SwiftUI 一致
# 导航栏标题颜色 → UIColor.appTextPrimary
# 导航栏按钮颜色 → UIColor.appPrimary
```

# Plan 2: 重建 ImageLoading 包

## 背景

`Packages/Utilities/ImageLoading/` 的目录结构已存在但源码文件全部被删除。本计划重新创建该 SPM 包的全部文件——`Package.swift`、三个门面 API 源码文件、以及测试文件。

## 修改目标

### 1. 恢复 Package.swift

**文件**：`Packages/Utilities/ImageLoading/Package.swift`

- platform: iOS 15, macOS 12
- 依赖：`Kingfisher` (`.upToNextMajor(from: "8.0.0")`)
- 对外 product：`ImageLoading`
- 两个 target：`ImageLoading` + `ImageLoadingTests`

### 2. 实现门面 API（3 个源码文件）

#### 2.1 `ImageLoadingConfiguration`

**文件**：`Packages/Utilities/ImageLoading/Sources/ImageLoading/ImageLoadingConfiguration.swift`

职责：统一配置模型，定义默认值。

```swift
public struct ImageLoadingConfiguration {
    /// 默认占位图（系统 SF Symbol）
    public static var defaultPlaceholderImage: Image? = Image(systemName: "photo")
    /// 默认失败图
    public static var defaultFailureImage: Image? = Image(systemName: "photo.badge.exclamationmark")
    /// 默认圆角样式
    public static var defaultCornerRadius: CGFloat = 8
    /// 默认裁剪模式
    public static var defaultContentMode: SwiftUI.ContentMode = .fill
}
```

#### 2.2 `AppRemoteImage`

**文件**：`Packages/Utilities/ImageLoading/Sources/ImageLoading/AppRemoteImage.swift`

职责：对外暴露的 SwiftUI View，内部使用 Kingfisher 的 `KFImage`。

接口设计（链式调用风格）：

```swift
AppRemoteImage(url: product.imageURL)
    .placeholder { ProgressView() }
    .failureImage(Image(systemName: "photo"))
    .cornerRadius(8)
    .contentMode(.fill)
```

关键点：
- 入口参数 `url: String?`——业务层传 URL 字符串，内部转换
- 使用 `KFImage` 实现，但业务代码不 import Kingfisher
- 列表场景支持 `resizable()` + `frame(width:height:)` 稳定布局
- 不使用 `.fade(duration:)` 等 Kingfisher 特有链式调用，确保降低耦合

#### 2.3 `ImageCacheBootstrap`

**文件**：`Packages/Utilities/ImageLoading/Sources/ImageLoading/ImageCacheBootstrap.swift`

职责：统一配置 Kingfisher 全局缓存参数。

```swift
public enum ImageCacheBootstrap {
    public static func configure(
        memoryCacheMB: Int = 100,
        diskCacheMB: Int = 500,
        cacheExpireDays: Int = 7
    ) {
        // 设置 ImageCache.default：
        // - memoryStorage.config.totalCostLimit
        // - diskStorage.config.sizeLimit
        // - diskStorage.config.expiration
    }
}
```

### 3. 测试文件

**文件**：`Packages/Utilities/ImageLoading/Tests/ImageLoadingTests/ImageLoadingTests.swift`

- `testAppRemoteImagePlaceholder`：验证 placeholder 存在
- `testConfigurationDefaultValues`：验证默认配置不崩溃
- `testCacheBootstrapConfigure`：验证 configure 方法不会崩溃
- `testAppRemoteImageWithNilURL`：验证 nil URL 显示占位图

## 注意事项

- 所有 `public` 类型不需要 `import Kingfisher`，仅在实现文件中 internal 使用
- `AppRemoteImage` 需要用 `@available(iOS 15, *)` 保护（因 KFImage 最低 iOS 14，保留此标记以明确）
- 保持文件在 200-400 行以内

## 验证方式

1. `cd Packages/Utilities/ImageLoading && swift build` 编译通过
2. `cd Packages/Utilities/ImageLoading && swift test` 测试通过
3. Kingfisher 依赖下载成功（`Package.resolved` 出现 Kingfisher 条目）

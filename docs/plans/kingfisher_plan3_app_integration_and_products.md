# Plan 3: App 层集成缓存配置 + ProductsFeature 接入图片展示

## 背景

Plan 2 重建了 ImageLoading 包后，需要在 App 层组合根调用全局缓存配置，并在 ProductsFeature 中将图片展示从纯文本替换为 `AppRemoteImage`。

## 步骤

### Step 1: ProductsFeature 添加 ImageLoading 依赖

**文件**：`Packages/Presentation/ProductsFeature/Package.swift`

- `dependencies` 数组添加 `.package(path: "../Utilities/ImageLoading")`
- `Utility` 枚举添加 `case ImageLoading`
- `.productsFeature` 的 `dependencies` 添加 `.utility(.ImageLoading)`

### Step 2: App 层调用 `ImageCacheBootstrap.configure()`

**文件**：`MyEcommerce/MyEcommerceApp.swift`

在 `init()` 方法顶部（或 DI 装配之前/之后）添加：

```swift
ImageCacheBootstrap.configure()
```

需要 `import ImageLoading`，放在已有 import 语句附近。

### Step 3: ProductListView 添加图片展示

**文件**：`Packages/Presentation/ProductsFeature/Sources/ProductsFeature/ProductList/ProductListView.swift`

在 `NavigationLink` 内的 `VStack` 上方添加商品缩略图：

```swift
// 示例结构
HStack {
    AppRemoteImage(url: product.imageURL)
        .frame(width: 60, height: 60)
        .cornerRadius(8)
    VStack(alignment: .leading) {
        Text(product.name).font(.appHeadline)
        Text(String(format: "%.2f €", product.price)).font(.appSubheadline)
    }
}
```

- 固定 `frame(width: 60, height: 60)` 防止布局跳动
- 使用 `.cornerRadius(.medium)` 与 DesignSystem 风格一致
- `HStack` 包裹图片和文字，图片在左

需要 `import ImageLoading`（UI 组件，无需额外桥接）。

### Step 4: ItemDetailView 添加大图展示

**文件**：`Packages/Presentation/ProductsFeature/Sources/ProductsFeature/ItemDetail/ItemDetailView.swift`

在 `VStack` 顶部添加商品大图：

```swift
AppRemoteImage(url: viewModel.product.imageURL)
    .frame(height: 250)
    .frame(maxWidth: .infinity)
    .clipped()
    .cornerRadius(.medium)
```

- 全宽、固定 250pt 高度的大图展示
- 添加 `.clipped()` 防止溢出
- 位于当前文字内容之上

## 涉及文件清单

| 文件 | 改动类型 |
|---|---|
| `Packages/Presentation/ProductsFeature/Package.swift` | 添加 ImageLoading 依赖 |
| `MyEcommerce/MyEcommerceApp.swift` | 添加 import + configure() 调用 |
| `Packages/Presentation/ProductsFeature/Sources/ProductsFeature/ProductList/ProductListView.swift` | 添加图片展示 |
| `Packages/Presentation/ProductsFeature/Sources/ProductsFeature/ItemDetail/ItemDetailView.swift` | 添加图片展示 |

## 验证方式

1. `xed .` 打开 Xcode → ⌘B 编译通过
2. `ImageCacheBootstrap.configure()` 在 App 启动时调用不崩溃
3. 商品列表每行左侧显示缩略图，详情页顶部显示大图
4. 图片加载后有缓存效果（重新进入不重复下载）

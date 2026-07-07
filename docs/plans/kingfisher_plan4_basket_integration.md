# Plan 4: BasketFeature 接入图片展示

## 背景

Plan 3 完成了 ProductsFeature 的图片展示接入，BasketFeature 也需要做相同的改造——添加 ImageLoading 依赖并在购物车列表展示商品缩略图。

## 步骤

### Step 1: BasketFeature 添加 ImageLoading 依赖

**文件**：`Packages/Presentation/BasketFeature/Package.swift`

改动模式与 ProductsFeature 完全一致：
- `dependencies` 添加 `.package(path: "../Utilities/ImageLoading")`
- `Utility` 枚举添加 `case ImageLoading` 及其 `.dependency` 计算属性
- `.basketFeature` 的 `dependencies` 添加 `.utility(.ImageLoading)`

### Step 2: BasketView 添加缩略图

**文件**：`Packages/Presentation/BasketFeature/Sources/BasketFeature/BasketView.swift`

当前 `ForEach` 内部的 `HStack` 只有文字：

```swift
HStack {
    VStack(alignment: .leading) { ... }
    Spacer()
    Text("Quantity: \(basket.quantity)")
    Spacer()
    Text(String(format:"%.2f", basket.price * Double(basket.quantity)))
}
```

改造为：

```swift
HStack {
    AppRemoteImage(url: basket.imageURL)
        .frame(width: 50, height: 50)
        .cornerRadius(.medium)
    VStack(alignment: .leading) {
        Text(basket.productName).font(.appHeadline)
        Text("price: \(String(format:"%.2f", basket.price))").font(.appSubheadline)
    }
    Spacer()
    Text("Quantity: \(basket.quantity)")
    Spacer()
    Text(String(format:"%.2f", basket.price * Double(basket.quantity)))
}
```

- 缩略图固定在 50x50，比商品列表略小以节省空间
- 购物车右侧已有数量和价格，图片放在 HStack 最左侧

需要 `import ImageLoading`。

## 涉及文件清单

| 文件 | 改动类型 |
|---|---|
| `Packages/Presentation/BasketFeature/Package.swift` | 添加 ImageLoading 依赖 |
| `Packages/Presentation/BasketFeature/Sources/BasketFeature/BasketView.swift` | 添加图片展示 |

## 验证方式

1. `cd Packages/Presentation/BasketFeature && swift build` 编译通过
2. 购物车列表每行左侧显示商品缩略图
3. 图片样式（圆角大小、占位图）与 ProductsFeature 保持一致

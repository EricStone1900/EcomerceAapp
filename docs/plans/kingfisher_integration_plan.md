# Kingfisher 图片加载框架集成实现计划

> 项目：EcommerceAppDemo（iOS · Clean Architecture · SPM 模块化）
> 文档：基于 `docs/specs/kingfisher_integration_plan.md` 的详细实现计划

---

## 一、当前状态分析

### 现状
- **无远程图片加载**：项目完全没有图片加载逻辑，无 `AsyncImage`、无 Kingfisher 等第三方库
- **数据模型无 imageUrl**：`ProductDTO`、`ProductDomainModel`、`MockDataFactory` 均无 `imageUrl` 属性
- **视图无图片展示**：`ProductListView`、`ItemDetailView`、`BasketView` 均只显示文本和价格
- **DesignSystem 无图片占位组件**：没有占位图、加载态等视觉组件

### 依赖关系
```
ImageLoading (新包, 依赖 Kingfisher)
    ↑
    ├── ProductsFeature (引用 ImageLoading)
    ├── BasketFeature (引用 ImageLoading)
    └── MyEcommerceApp (启动时调用 ImageCacheBootstrap.configure())
```

---

## 二、测试用图片 URL

使用 [Lorem Picsum](https://picsum.photos/) 和 [Placehold.co](https://placehold.co/) 作为测试图片源：

| 商品 | URL |
|------|-----|
| Product 1 | `https://picsum.photos/id/1/400/400` |
| Product 2 | `https://picsum.photos/id/20/400/400` |
| Product 3 | `https://picsum.photos/id/30/400/400` |
| Product 4 | `https://picsum.photos/id/40/400/400` |
| Product 5 | `https://picsum.photos/id/50/400/400` |
| Product 6 | `https://picsum.photos/id/60/400/400` |
| Product 7 | `https://picsum.photos/id/70/400/400` |
| Product 8 | `https://picsum.photos/id/80/400/400` |
| Product 9 | `https://picsum.photos/id/90/400/400` |
| Product 10 | `https://picsum.photos/id/100/400/400` |

> 注：picsum.photos 为稳定可靠的免费占位图服务，已运营多年，图片均为高质量摄影作品。

---

## 三、分阶段实施步骤

### Phase 1: 数据模型添加 imageUrl（4 个文件）

**目标**：在数据模型的各层添加 `imageUrl: String?` 属性，打通图片 URL 的数据链路。

#### 1.1 ProductDomainModelProtocol
**文件**：`Packages/Abstraction/Sources/Abstraction/ProductAbstraction/ProductDomainModelProtocol.swift`

添加属性：
```swift
var imageUrl: String? { get }
```

#### 1.2 ProductDomainModel
**文件**：`Packages/Domain/Sources/Domain/ProductDomain/ProductDomainModel.swift`

添加 `let imageUrl: String?` 存储属性，更新 `init` 和 `MemberwiseInit`。

#### 1.3 ProductDTO
**文件**：`Packages/Data/Sources/Data/ProductData/DTO/ProductDTO.swift`

添加 `let imageUrl: String?` 属性，确保遵循 `Decodable`（可选值，JSON 中不存在也不影响解析）。

#### 1.4 数据映射（ProductRepository）
**文件**：`Packages/Data/Sources/Data/ProductData/ProductRepository.swift`

在 DTO → Domain Model 转换时传递 `imageUrl`。

#### 1.5 MockDataFactory
**文件**：`Packages/Utilities/Networking/Sources/Networking/API/Mock/MockDataFactory.swift`

为 10 个 mock 商品添加对应的 picsum 图片 URL。

#### 1.6 验证
```bash
cd Packages/Domain && swift test --filter ProductDomainTests
cd Packages/Data && swift test --filter ProductDataTests
```

---

### Phase 2: 创建 ImageLoading 工具包（4 个新文件）

**目标**：新建 `Packages/Utilities/ImageLoading/` 包，封装 Kingfisher 为统一门面 API。

**采用 Pattern B（内联声明）**，与 `WaveAnimation` 模式一致——因为 ImageLoading 是简单包，无需多 target。

#### 2.1 Package.swift
**路径**：`Packages/Utilities/ImageLoading/Package.swift`

- swift-tools-version: 6.2
- platforms: .iOS(.v15)
- 外部依赖：`Kingfisher`（`https://github.com/onevcat/Kingfisher.git`, from: "8.0.0"）
- 唯一 target: `ImageLoading`

#### 2.2 AppRemoteImage.swift
**路径**：`Packages/Utilities/ImageLoading/Sources/ImageLoading/AppRemoteImage.swift`

对外暴露的 SwiftUI View。内部用 `KFImage` 实现，对外接口是纯 SwiftUI 语法。

```swift
public struct AppRemoteImage: View {
    private let url: URL?
    private var placeholder: AnyView?
    private var failureImage: AnyView?
    
    public init(url: URL?) { ... }
    
    public var body: some View {
        KFImage(url)
            .placeholder { placeholder }
            .onFailure { _ in failureImage }
            ...
    }
}

// 链式配置
extension AppRemoteImage {
    public func placeholder<Placeholder: View>(@ViewBuilder _ content: () -> Placeholder) -> AppRemoteImage
    public func onFailure<Content: View>(@ViewBuilder _ content: () -> Content) -> AppRemoteImage
}
```

**关键设计决策：**
- 不直接暴露 `KFImage` 或其配置 API
- 提供有限但够用的配置方法（占位图、失败图）
- 圆角、裁剪等常见样式通过门面方法暴露
- 使用 `@State` 不可变拷贝模式（每次配置方法返回新实例）

#### 2.3 ImageLoadingConfiguration.swift
**路径**：`Packages/Utilities/ImageLoading/Sources/ImageLoading/ImageLoadingConfiguration.swift`

统一配置模型：

```swift
public struct ImageLoadingConfiguration {
    public var placeholderColor: Color
    public var failureIconName: String
    public var cornerRadius: CGFloat
    public var transitionDuration: TimeInterval
    
    public static let `default` = ImageLoadingConfiguration(...)
}
```

使用 DesignSystem 的令牌（如果可用），否则使用合理默认值。

#### 2.4 ImageCacheBootstrap.swift
**路径**：`Packages/Utilities/ImageLoading/Sources/ImageLoading/ImageCacheBootstrap.swift`

全局缓存配置入口：

```swift
public struct ImageCacheBootstrap {
    public static func configure(
        memoryCacheLimitMB: Int = 100,
        diskCacheLimitMB: Int = 500,
        cacheExpirationDays: Int = 7
    ) { ... }
}
```

#### 2.5 验证
```bash
cd Packages/Utilities/ImageLoading && swift build
```

---

### Phase 3: App 层接入（1 个文件 + Xcode 配置）

**目标**：在 App 启动时配置 Kingfisher 全局缓存。

#### 3.1 MyEcommerceApp.swift
**文件**：`MyEcommerce/MyEcommerceApp.swift`

在 `init()` 最开头添加 `ImageCacheBootstrap.configure()` 调用（在 DI 注册之前）。

#### 3.2 Xcode 项目配置
ImageLoading 包通过 Xcode 的自动 SPM 依赖解析加入项目，无需修改 `project.pbxproj`。

---

### Phase 4: ProductsFeature 集成（2 个文件修改）

**目标**：商品列表和商品详情页添加远程图片加载。

#### 4.1 ProductsFeature/Package.swift
**路径**：`Packages/Presentation/ProductsFeature/Package.swift`

在 Utility enum 中添加 `.ImageLoading` case：
```swift
case ImageLoading
var dependency: Target.Dependency {
    switch self {
    case .ImageLoading:
        .product(name: "ImageLoading", package: "ImageLoading")
    // ...
    }
}
```

在 `ProductsFeature` target 的 `dependencies` 中添加 `.utility(.ImageLoading)`。

#### 4.2 ProductListView.swift
**路径**：`Packages/Presentation/ProductsFeature/Sources/ProductsFeature/ProductList/ProductListView.swift`

列表行中添加产品缩略图（左侧 60x60 圆角图片）：
```swift
HStack(spacing: .spacingM) {
    AppRemoteImage(url: product.imageUrl.flatMap(URL.init(string:)))
        .placeholder { Color.appBackground }
        .frame(width: 60, height: 60)
        .designCornerRadius(.medium)
    VStack(alignment: .leading) {
        Text(product.name).font(.appBody)
        Text(product.price).font(.appCaption).foregroundColor(.appTextSecondary)
    }
}
```

#### 4.3 ItemDetailView.swift
**路径**：`Packages/Presentation/ProductsFeature/Sources/ProductsFeature/ItemDetail/ItemDetailView.swift`

商品详情顶部添加大图（全宽，250pt 高）：
```swift
AppRemoteImage(url: product.imageUrl.flatMap(URL.init(string:)))
    .placeholder { ProgressView() }
    .frame(height: 250)
    .frame(maxWidth: .infinity)
    .designCornerRadius(.large)
```

---

### Phase 5: BasketFeature 集成（2 个文件修改）

**目标**：购物车列表添加商品缩略图。

#### 5.1 BasketFeature/Package.swift
**路径**：`Packages/Presentation/BasketFeature/Package.swift`

与 ProductsFeature 相同的模式添加 ImageLoading 依赖。

#### 5.2 BasketView.swift
**路径**：`Packages/Presentation/BasketFeature/Sources/BasketFeature/BasketView.swift`

购物车行添加商品缩略图（左侧 50x50 圆角图片）：
```swift
HStack(spacing: .spacingM) {
    AppRemoteImage(url: item.imageUrl.flatMap(URL.init(string:)))
        .placeholder { Color.appBackground }
        .frame(width: 50, height: 50)
        .designCornerRadius(.medium)
    VStack(alignment: .leading) { ... }
}
```

**注意**：`BasketDomainModelProtocol` 目前没有 `imageUrl`。购物车的 `imageUrl` 可以通过两种方式获取：
- **方案 A（推荐）**：从 `ProductAbstraction` 层获取商品信息，购物车只存 `productID`
- **方案 B**：在 `BasketItemDTO` 中添加 `imageUrl`，从 API 返回数据中获取

**实施选择**：采用方案 B，因为购物车通常会在添加商品时携带商品图片 URL，避免额外查询。

---

## 四、文件变更清单总览

| 阶段 | 操作 | 文件 |
|------|------|------|
| Phase 1 | 修改 | `Abstraction/.../ProductDomainModelProtocol.swift` |
| Phase 1 | 修改 | `Domain/.../ProductDomainModel.swift` |
| Phase 1 | 修改 | `Data/.../ProductDTO.swift` |
| Phase 1 | 修改 | `Data/.../ProductRepository.swift` |
| Phase 1 | 修改 | `Networking/.../MockDataFactory.swift` |
| Phase 1 | 新增 | `Utilities/ImageLoading/Package.swift` |
| Phase 2 | 新增 | `Utilities/ImageLoading/Sources/ImageLoading/AppRemoteImage.swift` |
| Phase 2 | 新增 | `Utilities/ImageLoading/Sources/ImageLoading/ImageLoadingConfiguration.swift` |
| Phase 2 | 新增 | `Utilities/ImageLoading/Sources/ImageLoading/ImageCacheBootstrap.swift` |
| Phase 3 | 修改 | `MyEcommerce/MyEcommerceApp.swift` |
| Phase 4 | 修改 | `ProductsFeature/Package.swift` |
| Phase 4 | 修改 | `ProductsFeature/.../ProductListView.swift` |
| Phase 4 | 修改 | `ProductsFeature/.../ItemDetailView.swift` |
| Phase 5 | 修改 | `BasketFeature/Package.swift` |
| Phase 5 | 修改 | `BasketFeature/.../BasketView.swift` |

---

## 五、验证方案

### 编译验证
```bash
xed .
# Xcode 打开后 Cmd+B 编译验证
```

### 单测验证
```bash
# 验证 domain 层数据模型变更
cd Packages/Domain && swift test --filter ProductDomainTests

# 验证 data 层映射
cd Packages/Data && swift test --filter ProductDataTests
```

### 功能验证
1. **商品列表**：每个商品行左侧显示缩略图（60x60 圆角）
2. **商品详情**：顶部显示商品大图（全宽 ~250pt 高）
3. **购物车**：每行左侧显示缩略图（50x50 圆角）
4. **缓存**：二次进入同一页面，图片不重新下载（Xcode Network 面板验证）
5. **断网**：断网时显示统一的失败占位图
6. **Mock 模式**：`-environment dev` 运行，验证 Mock 10 个商品均有图片

### 滚动性能
- 商品列表快速滑动，验证无明显掉帧
- 下采样确保列表项图片按实际展示尺寸解码

---

## 六、验收标准

- [ ] `ProductsFeature`、`BasketFeature` 均不直接 `import Kingfisher`，只依赖 `ImageLoading` 包
- [ ] 所有 10 个 Mock 商品均有对应占位图展示
- [ ] 图片加载过程中显示占位图（灰色背景），加载完成后平滑过渡
- [ ] URL 为空或加载失败时显示统一失败占位图，不崩溃
- [ ] 全局缓存策略只在 App 层配置一次，Feature 包无需关心底层细节
- [ ] 列表滚动流畅，无因图片解码导致的明显掉帧
- [ ] 所有新增代码遵循不可变（immutable）模式
- [ ] 所有新增 UIView 使用 DesignSystem 的语义化令牌

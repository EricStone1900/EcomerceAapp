# Kingfisher 图片加载框架集成实现计划

> 项目：EcommerceAppDemo（iOS · Clean Architecture · SPM 模块化）
> 目标：接入 Kingfisher（https://github.com/onevcat/Kingfisher.git），为 ProductsFeature、BasketFeature 等提供统一的远程图片加载能力
> 说明：本文档为实现计划，不含具体代码实现

---

## 一、项目整体架构解析

项目采用 **Clean Architecture + SPM 模块化**，严格依赖倒置：外层依赖内层协议，内层不知道外层的存在。

```
Presentation/Features  →  Domain  →  Abstraction  ←  Data
        │                                           ↑
        │                    ┌──────────────────────┘
        └──── Utilities ─────┘
```

| 层 | 职责 | 依赖规则 |
|---|---|---|
| **Abstraction** | 纯协议层 | 仅 Swinject/RxSwift；UIKit 不算"项目依赖" |
| **Domain** | UseCase 业务编排 | 仅依赖 Abstraction 协议 |
| **Data** | Repository/Service 具体实现 | 依赖 Abstraction 协议 |
| **Presentation** | SwiftUI Feature 包（`LoginFeature`/`ProductsFeature`/`BasketFeature`/`WebContainerFeature`） | 依赖 Domain 协议、Abstraction、Utilities |
| **Utilities** | 横切工具，被所有 Feature 共用（如 `Analytics`、`Networking`、`Utils`） | 可依赖 Abstraction 协议，最小外部依赖 |
| **App 层**（`MyEcommerce/`） | 组合根，DI 装配、聚合各 Feature | 唯一允许"知道所有 Feature"的层 |

**目录结构**：

```
Packages/
├── Abstraction/
├── Domain/
├── Data/
├── Presentation/
│   ├── LoginFeature/
│   ├── ProductsFeature/
│   ├── BasketFeature/
│   └── WebContainerFeature/
└── Utilities/
    ├── Networking/API/
    ├── Utils/
    ├── Analytics/
    └── (ImageLoading/ 待新建)
```

**本次集成的定位判断**：Kingfisher 是第三方图片加载/缓存库，属于横切基础设施，跟之前接入的 `DesignSystem` 是同一类问题——不希望业务 Feature 包直接依赖第三方库细节。因此新建统一封装包 `ImageLoading`，放进 `Packages/Utilities/`，业务方只调用封装后的组件，Kingfisher 作为实现细节被隐藏。以后想换成 SDWebImage/Nuke，或者统一调整缓存策略，只改这一个包，不用动任何 Feature 代码。

## 如何使用现有工程

- `xed .` 打开工程，DEBUG 默认走 Mock API（`-environment dev`），无需后端即可跑通全流程
- 新增 Utilities 层组件的标准套路：新建 SPM 包 → 引入第三方依赖 → 封装成统一门面 API → 各 Feature 包在自己的 `Package.swift` 里加本地路径依赖引用
- 单测：`cd Packages/Utilities/<包名> && swift test`

---

## 二、新建模块：`ImageLoading`

- 路径：`Packages/Utilities/ImageLoading/`
- 依赖：Kingfisher（SPM 远程依赖 `https://github.com/onevcat/Kingfisher.git`）

### 包内结构

```
ImageLoading/
└── Sources/ImageLoading/
    ├── AppRemoteImage.swift              # 对外暴露的 SwiftUI View（门面）
    ├── ImageLoadingConfiguration.swift   # 占位图/失败图/圆角/缓存策略的配置模型
    └── ImageCacheBootstrap.swift         # App 启动时的全局缓存配置入口
```

### 各文件职责

- **`AppRemoteImage`**：内部用 `KFImage` 实现，对外接口是纯 SwiftUI 语法，如 `AppRemoteImage(url: product.imageURL)`，支持链式调用配置：
  - `.placeholder { ProgressView() }`：加载中占位视图
  - `.onFailure { ... }` / 统一失败占位图
  - 圆角、裁剪方式等常见图片展示样式
  - 风格与现有 `DesignSystem`/`ComponentKit` 的组件保持一致，业务方看不出底层用的是 Kingfisher 还是别的库
- **`ImageLoadingConfiguration`**：统一约定默认占位图、默认失败图、默认圆角样式；如果 `DesignSystem` 已经建好，占位图背景色、圆角直接读取设计令牌，不重复定义视觉规范
- **`ImageCacheBootstrap`**：提供一个 `configure()` 方法，统一设置 Kingfisher 的全局缓存参数（内存缓存上限、磁盘缓存上限、过期策略、是否开启渐进式 JPEG），Feature 包不需要关心这些底层细节

---

## 三、全局缓存策略配置（App 层组合根）

- 在 `MyEcommerceApp.init()` 中调用 `ImageCacheBootstrap.configure()`，与现有 DI 装配逻辑放在一起，风格保持一致
- 需要确定的具体参数（建议先给出合理默认值，后续可按实际内存/磁盘表现调优）：
  - 内存缓存上限（避免商品列表图片过多导致内存暴涨）
  - 磁盘缓存上限与过期时间（例如 7 天未访问自动清理）
  - 是否开启渐进式 JPEG 加载（改善大图加载体验）

---

## 四、接入 ProductsFeature 和 BasketFeature

### 1. 依赖接入

- `ProductsFeature`、`BasketFeature` 的 `Package.swift` 里各自加对 `ImageLoading` 的依赖（不直接依赖 Kingfisher 本身，保持 Feature 包与第三方库解耦）

### 2. 替换现有图片展示逻辑

- 商品列表（`ProductListView`）、商品详情（`ProductDetailView`）、购物车列表（`BasketView`）里原本用 `AsyncImage` 或占位 `Image(systemName:)` 的地方，替换为 `AppRemoteImage(url:)`

### 3. 列表场景的性能优化重点

- **图片下采样（downsampling）**：按实际展示尺寸而非原图尺寸解码，减少内存占用，这对商品列表这种一屏多图的场景尤其重要
- **布局稳定性**：用固定尺寸容器 + 占位图承托布局，避免图片加载完成前后页面出现跳动
- **预加载评估**：视商品列表滑动体验需要，评估是否使用 Kingfisher 的 `ImagePrefetcher` 提前预热即将进入可视区域的图片

---

## 五、错误处理与占位状态

- **加载中**：显示占位图/loading 指示器，复用 `DesignSystem` 的加载态样式（如果已建好）
- **URL 为空或加载失败**：显示统一的失败占位图，而不是空白或系统崩溃图标，确保 `ProductsFeature`、`BasketFeature` 等各处表现一致
- 失败占位图和加载占位图的样式，统一在 `ImageLoadingConfiguration` 里定义默认值，业务方一般不需要每次都手动传，除非有特殊场景

---

## 六、分阶段实施步骤

1. **搭建基础**：新建 `ImageLoading` 包，加 Kingfisher 远程依赖，跑通编译
2. **实现门面 API**：完成 `AppRemoteImage`、`ImageLoadingConfiguration`、`ImageCacheBootstrap` 三个文件
3. **全局缓存配置**：App 层组合根接入 `ImageCacheBootstrap.configure()`
4. **ProductsFeature 试点替换**：商品列表 + 商品详情页，验证加载、缓存、占位效果
5. **BasketFeature 替换**：购物车列表，验证与 ProductsFeature 表现一致
6. **列表性能优化**：接入下采样，视需要接入预加载
7. **错误占位状态统一验收**：模拟断网、错误 URL 等场景
8. **文档收尾**：更新 `docs/architecture.md` 补充 `ImageLoading` 模块说明；更新 `CLAUDE.md`，约定"展示远程图片一律使用 `ImageLoading` 包的 `AppRemoteImage`，不直接使用 Kingfisher 或系统 `AsyncImage`"

---

## 七、验收标准总览

- [ ] `ProductsFeature`、`BasketFeature` 均不直接 import Kingfisher，只依赖 `ImageLoading` 包
- [ ] 商品图片能正常加载、缓存生效（同一图片二次进入页面不重复下载，可用 Xcode Network 面板验证）
- [ ] 列表滚动流畅，无因图片解码导致的明显掉帧（可用 Instruments 的 Time Profiler / Core Animation 验证）
- [ ] 加载失败场景（断网或错误 URL）有统一的失败占位图，不崩溃
- [ ] 全局缓存策略只在 App 层配置一次，Feature 包无需关心底层细节
- [ ] 以后如需更换图片加载库，只需改动 `ImageLoading` 包内部实现，所有 Feature 包调用代码零改动

---

*本文档为实现计划，不含具体代码实现。*

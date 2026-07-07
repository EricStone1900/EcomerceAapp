# Plan 5: 性能优化、错误占位验收与文档收尾

## 背景

前 4 个计划完成了图片加载功能的基本链路，本计划在已有基础上进行性能优化、确保错误占位状态一致性，并更新项目文档。

## 步骤

### Step 1: 列表图片下采样（Downsampling）

**文件**：`Packages/Utilities/ImageLoading/Sources/ImageLoading/AppRemoteImage.swift`

在 `KFImage` 创建时添加下采样处理器：

```swift
// 在 KFImage(url) 之前或通过 .setProcessor 添加
// 使用 Kingfisher 的 DownsamplingImageProcessor
// 尺寸根据传入的 frameSize 参数动态计算
```

实现思路：
- `AppRemoteImage` 内部维护一个 `targetSize: CGSize` 属性
- 内部调用 `.setProcessor(DownsamplingImageProcessor(size: targetSize))`
- 默认值从 `ImageLoadingConfiguration` 读取（如 300x300）
- 链式 API 支持 `.downsampling(size:)` 覆盖默认值

**为什么下采样重要**：商品列表一屏显示 4-5 行，如果每张图都以原图尺寸（可能 1200px+）解码到内存，会急剧增加内存压力，导致滚动掉帧甚至 OOM。下采样让 Kingfisher 以显示尺寸解码，内存占用降低 90%+。

### Step 2: 预加载评估（可选）

如果列表滑动时图片加载有明显延迟，在 `ProductListViewModel` 中添加预加载逻辑：

- 使用 Kingfisher 的 `ImagePrefetcher` 在视图出现时预加载可见区域商品的图片 URL 列表
- 封装在 `ImageCacheBootstrap` 或独立的工具方法中，不暴露 Kingfisher 类型给业务层

```swift
// ImageLoading 内部方法
func prefetchImages(urls: [String]) {
    let kingfisherURLs = urls.compactMap { URL(string: $0) }
    ImagePrefetcher(urls: kingfisherURLs).start()
}
```

### Step 3: 错误占位状态验收

模拟以下场景并截图验证：

| 场景 | 验证方法 | 期望结果 |
|---|---|---|
| 正常加载 | 启动 App 浏览商品 | 图片正常显示 |
| URL 为空 | 使用 `nil` 测试 | 显示默认占位图（photo SF Symbol） |
| 加载失败 | 关闭网络后浏览 | 显示失败占位图（photo.badge.exclamationmark） |
| 断网重连 | 关闭网络→打开网络 | 恢复显示已缓存图片，新图片自动加载 |
| 快速滚动 | 快速上下滑动商品列表 | 无明显占位闪烁，布局不跳动 |

### Step 4: 文档收尾

1. **更新 `docs/architecture.md`**（如果存在）：补充 `ImageLoading` 模块在 Utilities 层中的位置说明

2. **更新 `CLAUDE.md`**：
   - 在 DesignSystem Usage 区域后增加一段：
     ```
     ## ImageLoading Usage
     
     展示远程图片一律使用 `ImageLoading` 包的 `AppRemoteImage`，不直接使用 Kingfisher 或系统 `AsyncImage`：
     
     ```swift
     import ImageLoading
     
     AppRemoteImage(url: product.imageURL)
         .frame(width: 60, height: 60)
         .cornerRadius(.medium)
     ```
     
     不要直接 import Kingfisher 使用 `KFImage`，所有 Feature 包应只依赖 `ImageLoading`。
     ```
   - 在 Package Count 和 Docs 区域确认无误

## 涉及文件清单

| 文件 | 改动类型 |
|---|---|
| `Packages/Utilities/ImageLoading/Sources/ImageLoading/AppRemoteImage.swift` | 添加下采样支持 |
| `Packages/Utilities/ImageLoading/Sources/ImageLoading/ImageLoadingConfiguration.swift` | 添加默认下采样尺寸 |
| `Packages/Utilities/ImageLoading/Sources/ImageLoading/ImageCacheBootstrap.swift` | 可选：添加预加载方法 |
| `CLAUDE.md` | 添加 ImageLoading 使用约定 |

## 验收标准（来自原计划文档）

- [ ] `ProductsFeature`、`BasketFeature` 均不直接 import Kingfisher，只依赖 `ImageLoading` 包
- [ ] 商品图片能正常加载、缓存生效（同一图片二次进入页面不重复下载）
- [ ] 列表滚动流畅，无因图片解码导致的明显掉帧
- [ ] 加载失败场景（断网或错误 URL）有统一的失败占位图
- [ ] 全局缓存策略只在 App 层配置一次，Feature 包无需关心底层细节
- [ ] 以后如需更换图片加载库，只需改动 `ImageLoading` 包内部实现，所有 Feature 包调用代码零改动

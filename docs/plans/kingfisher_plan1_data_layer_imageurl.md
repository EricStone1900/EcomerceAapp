# Plan 1: 数据层添加 imageURL 属性

## 背景

当前产品（Product）和购物车（Basket）的领域模型和数据模型中均缺少 `imageURL` 字段，视图层无法获取图片 URL 来展示商品图片。本计划在数据链路各层添加 `imageURL` 属性，为后续图片展示提供数据基础。

## 修改目标

为 Product 和 Basket 两条数据链路添加 `imageURL: String?` 属性：

### 产品链路（5 处修改）

| 文件 | 改动 |
|---|---|
| `Packages/Abstraction/.../ProductDomainModelProtocol.swift` | 协议添加 `var imageURL: String? { get }` |
| `Packages/Data/.../DTO/ProductDTO.swift` | 结构体添加 `let imageURL: String?` + `CodingKeys`（蛇形映射 `image_url`） |
| `Packages/Data/.../ProductRepository/ProductDomainModel.swift` | 结构体添加 `public let imageURL: String?` |
| `Packages/Utilities/Networking/.../Mock/MockDataFactory.swift` | `MockProduct` 添加 `let imageURL: String?`，10 个 mock 产品添加有意义的图片 URL |
| `Packages/Data/.../ProductRepository/ProductRepository.swift` | DTO→DomainModel 映射时传递 `imageURL` |

### 购物车链路（4 处修改）

| 文件 | 改动 |
|---|---|
| `Packages/Abstraction/.../BasketDomainModelProtocol.swift` | 协议添加 `var imageURL: String? { get }` |
| `Packages/Data/.../DTO/BasketItemDTO.swift` | 结构体添加 `let imageURL: String?` |
| `Packages/Data/.../DomainModel/BasketDomainModel.swift` | 结构体添加 `public let imageURL: String?` |
| `Packages/Data/.../BasketRepository/BasketRepository.swift` | DTO→DomainModel 映射时传递 `imageURL` |

## 图片 URL 选择方案

使用以下可公开访问的占位图服务（无需 `/` 认证、无防盗链）：

### picsum.photos（真实照片，推荐）

```
https://picsum.photos/id/10/300/300  → 森林景观（通用品类感）
https://picsum.photos/id/1/300/300   → 键盘/桌面（适合电子产品）
https://picsum.photos/id/20/300/300  → 动物（装饰品类）
https://picsum.photos/id/30/300/300  → 建筑线条
https://picsum.photos/id/40/300/300  → 植物/自然
https://picsum.photos/id/50/300/300  → 风景
https://picsum.photos/id/60/300/300  → 工业设计
https://picsum.photos/id/70/300/300  → 城市风光
https://picsum.photos/id/80/300/300  → 道路/旅行
https://picsum.photos/id/90/300/300  → 静物
```

### placehold.co（纯色占位图，后备方案）

```
https://placehold.co/300x300/EEE/31343C?text=MacBook+Pro
https://placehold.co/300x300/EEE/31343C?text=iPhone
```

## Mock 数据映射

对 10 个 Mock 产品，按品类分配 picsum 图片 ID：

| 产品 | 推荐图片 URL |
|---|---|
| MacBook Pro 16-inch M3 Max | `https://picsum.photos/id/0/300/300`（笔记本/工作站） |
| iPhone 16 Pro Max 256GB | `https://picsum.photos/id/1/300/300`（科技感） |
| AirPods Pro 2nd Gen | `https://picsum.photos/id/2/300/300` |
| iPad Air 13-inch M2 | `https://picsum.photos/id/3/300/300` |
| Apple Watch Ultra 2 | `https://picsum.photos/id/4/300/300` |
| Mac mini M4 Pro | `https://picsum.photos/id/5/300/300` |
| Apple AirTag 4-Pack | `https://picsum.photos/id/6/300/300` |
| Belkin BoostCharge Pro | `https://picsum.photos/id/7/300/300` |
| AirPods Max | `https://picsum.photos/id/8/300/300` |
| Apple Pencil Pro | `https://picsum.photos/id/9/300/300` |

> **注意**：picsum.photos 部分 ID 可能返回 404，如遇到可换用其他 ID 或回退到 placehold.co。

## 验证方式

1. `cd Packages/Abstraction && swift build` 编译通过
2. `cd Packages/Data && swift build` 编译通过
3. `cd Packages/Utilities/Networking && swift build` 编译通过
4. 协议层和实现层 `imageURL` 类型签名一致（都是 `String?`）

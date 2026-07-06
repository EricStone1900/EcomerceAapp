# 阶段 4（可选）：阴影规范 + UIKit 兼容层

> 前置依赖：阶段 1-3（颜色、字体、圆角/间距令牌）已完成
> 说明：本文档为实施计划，不含具体代码实现

---

## 项目整体架构解析

项目采用 **Clean Architecture + SPM 模块化**，五层结构，依赖方向由外向内收敛：

```
Presentation/Features  →  Domain  →  Abstraction  ←  Data
        │                                           ↑
        │                    ┌──────────────────────┘
        └──── Utilities ─────┘
```

工程是 UIKit 导航容器（\`UINavigationController\`）承载 SwiftUI 内容的混合结构，因此设计令牌需要同时被 SwiftUI 与 UIKit 两侧代码取用。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程
- 单测：\`cd Packages/Utilities/DesignSystem && swift test\`


---

## 上文衔接

阶段 1-3 已完成颜色、字体字号、圆角、间距四类核心设计令牌，均已在部分页面验证生效。本阶段是可选阶段，视实际 UI 需求决定是否执行。

## 本阶段目标

补充统一阴影规范（如果 UI 稿中有用到卡片阴影等效果），并打通 UIKit 侧对同一套设计令牌的取用能力，避免出现"SwiftUI 一套颜色、UIKit 又硬编码另一套颜色"的两套标准问题。

## 需要实现的内容

### 1. 阴影规范（视需要决定是否做）

- 定义协议 `ShadowTokensProviding`，声明阴影槽位（如 `card`、`elevated`），每个槽位包含颜色、透明度、模糊半径、偏移量
- 在 `DefaultDesignTheme` 中实现

### 2. UIKit 兼容层

- 提供 `UIColor+DesignSystem.swift`：与 SwiftUI 的 `Color` 令牌对应的 `UIColor` 便捷扩展，直接复用同一份 Asset Catalog Color Set
- 提供 `UIFont+DesignSystem.swift`：与 SwiftUI 的 `Font` 令牌对应的 `UIFont` 便捷扩展
- 如果工程里已经/正在实现统一导航栏基类（`BaseNavigationController` 之类），本阶段需要回头检查该基类内部是否有硬编码的颜色/字体设置，改为引用 `DesignSystem` 的 UIKit 兼容层令牌

## 验收清单

- [ ] （如实现阴影）至少一个卡片类组件使用统一阴影令牌
- [ ] UIKit 侧（如导航栏、TabBar）的颜色/字体来源于 `DesignSystem` 的 UIKit 兼容层，不再硬编码具体色值
- [ ] SwiftUI 与 UIKit 两侧对同一个语义槽位（如 `primary`）取到的是同一份视觉效果，验证一次颜色改动能同步影响两侧

## 下一阶段预告

阶段 5 是收尾阶段：把现有 Feature 包内剩余的硬编码颜色/字体/圆角/间距全部替换为设计令牌引用，并更新项目文档。

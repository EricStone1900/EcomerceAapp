# 阶段 3：圆角与间距规范

> 前置依赖：阶段 1（颜色令牌）、阶段 2（字体字号）已完成
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

本次工作全部落在 \`Packages/Utilities/DesignSystem/\` 包内。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程
- 单测：\`cd Packages/Utilities/DesignSystem && swift test\`


---

## 上文衔接

阶段 1、2 已完成颜色令牌与字体字号令牌，均已在至少一个页面验证替换效果。本阶段继续在 `DesignSystem` 包内补充圆角与间距规范。

## 本阶段目标

统一卡片、按钮等组件的圆角取值，以及页面间距（padding/spacing）取值，避免各处自由发挥导致视觉不一致。

## 需要实现的内容

- 定义协议 `RadiusTokensProviding`，声明圆角槽位，如 `small`、`medium`、`large`、`pill`（全圆角，用于胶囊按钮等场景）
- 定义协议 `SpacingTokensProviding`，声明间距槽位，建议采用统一网格（如 4pt 或 8pt 网格），命名如 `xs`、`s`、`m`、`l`、`xl`，具体数值以现有 UI 稿实际使用的间距为准
- 在 `DefaultDesignTheme` 中实现以上两个协议
- 提供便捷调用方式：
  - `.designCornerRadius(.medium)` 这样的 ViewModifier
  - 间距令牌可以是简单的静态数值常量引用，或封装进常用的 Stack 便捷初始化方法

## 验收清单

- [ ] 现有卡片类、按钮类组件的圆角替换为使用统一令牌
- [ ] 至少一个页面的间距值（List/Stack 的 padding、spacing）替换为使用间距令牌（不要求一次性全部替换完，允许后续阶段继续扩展覆盖范围）
- [ ] 圆角与间距槽位数量控制在个位数，避免定义过多用不上的档位

## 下一阶段预告

阶段 4（可选）将视需要补充统一阴影规范，以及为 UIKit 侧（如导航栏）提供等价的颜色/字体便捷扩展，确保 SwiftUI 与 UIKit 使用同一套设计令牌来源。

# 阶段 2：字体字号规范

> 前置依赖：阶段 1（DesignSystem 包骨架 + 颜色令牌）已完成
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

本次工作全部落在 \`Packages/Utilities/DesignSystem/\` 包内，与业务 Feature 包保持零耦合。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程
- 单测：\`cd Packages/Utilities/DesignSystem && swift test\`


---

## 上文衔接

阶段 1 已完成 `DesignSystem` 包的骨架搭建与颜色令牌体系，颜色支持深色模式自动适配，并已在至少一个页面完成替换验证。本阶段在同一个包里继续扩展字体字号能力。

## 本阶段目标

梳理现有 UI 里实际用到的字号档位，归纳成有限的几个语义化槽位，替代散落在各处的"魔法数字"字号。

## 需要实现的内容

- 定义协议 `TypographyTokensProviding`，声明字体字号槽位，建议先梳理出：`largeTitle`、`title`、`headline`、`body`、`caption` 这几档（具体档位数量以现有 UI 稿实际用到的样式为准，不要凭空发明用不上的档位）
- 每个槽位对应：字体（系统字体或自定义字体）、字号、字重
- 在 `DefaultDesignTheme` 中实现 `TypographyTokensProviding`
- 提供便捷调用方式，如 `.appFont(.title)` 这样的 ViewModifier 或 `Font` 静态属性

## 需要确认的关键决策

- **是否需要支持 Dynamic Type（系统字体大小无障碍设置）**：如果需要，字体令牌应基于 `Font.TextStyle`/`UIFontMetrics` 实现，能随系统字体大小设置自动缩放；如果暂不需要，用固定像素值即可，但建议在协议设计时留好扩展空间，避免以后要支持时被迫改动所有调用方代码

## 验收清单

- [ ] 现有至少一个页面的标题和正文文字，替换为使用字体令牌
- [ ] 已明确本阶段是否支持 Dynamic Type，并在实现中体现该决策
- [ ] 字体槽位命名为语义化命名（如 `headline`），不是"16pt粗体"这种描述性命名

## 下一阶段预告

阶段 3 将补充圆角与间距规范（`RadiusTokensProviding`、`SpacingTokensProviding`）。

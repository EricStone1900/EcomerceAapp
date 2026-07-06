# 阶段 1：搭建 DesignSystem 包骨架 + 颜色令牌

> 本阶段可独立执行，是整个 Design System 的地基
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

实际目录对应：\`Packages/{Abstraction, Domain, Data, Presentation, Utilities}/\`。本次的 \`DesignSystem\` 属于横切基础设施，放在 \`Packages/Utilities/DesignSystem/\`，与 \`Analytics\`、\`Networking\`、\`Utils\` 同级，任何 Feature 包都可以直接依赖它，它不依赖任何业务 Feature 包。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API（\`-environment dev\`），无需后端即可跑通全流程
- 单测：\`cd Packages/Utilities/DesignSystem && swift test\`


---

## 本阶段目标

新建 `DesignSystem` SPM 包，实现颜色令牌体系，并保证深色/浅色模式自动适配。

## 设计原则

- 颜色以**语义名**命名（如 `primary`、`textSecondary`、`error`），不用"色值描述"命名（不叫 `blue`、`darkGray`），这样以后换色板不用改调用方代码
- 颜色通过**协议**暴露（`ColorTokensProviding`），页面统一从协议取值，不直接引用具体实现类型，为以后动态换肤/主题预留扩展口子
- 颜色值优先放进 **Asset Catalog 的 Color Set**，同时配置 Any Appearance 与 Dark Appearance，深色模式自动生效，不需要代码里写 if/else 判断

## 需要实现的内容

- 新建 SPM 包 `DesignSystem`，路径 `Packages/Utilities/DesignSystem/`
- 包内建 `Assets.xcassets`，为每个语义颜色槽位建一个 Color Set（`primary`、`secondary`、`background`、`textPrimary`、`textSecondary`、`success`、`warning`、`error` 等，具体槽位可结合现有 UI 稿再调整增减），逐一配置浅色/深色两套取值
- 定义协议 `ColorTokensProviding`，声明上述颜色槽位
- 实现 `DefaultDesignTheme` 中颜色部分，遵循 `ColorTokensProviding`，内部引用 Asset Catalog 的 Color Set
- 提供 SwiftUI 便捷接入：
  - `Color+DesignSystem.swift`：便捷调用方式（如 `Color.appPrimary` 或通过主题对象取值，二选一，视团队习惯定）
  - `DesignThemeEnvironmentKey.swift`：通过 `EnvironmentKey`/`EnvironmentValues` 把当前主题注入 View 树，页面用 `@Environment(\.designTheme)` 取值

## 验收清单

- [ ] 包可独立编译通过
- [ ] 深色/浅色模式切换（模拟器 Settings 或 Xcode 预览的 Appearance 切换）下，颜色令牌能自动响应，无需重启 App
- [ ] 至少挑一个已有页面，把其中硬编码的颜色值替换成新颜色令牌，视觉效果与替换前一致（无回归）
- [ ] 颜色槽位命名均为语义化命名，没有出现"blue"/"gray1"这类描述性命名

## 下一阶段预告

阶段 2 将在 `DesignSystem` 包基础上，补充字体字号规范（`TypographyTokensProviding`），梳理现有 UI 里实际用到的字号档位。

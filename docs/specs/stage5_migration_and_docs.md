# 阶段 5：现有 Feature 全量替换与文档收尾

> 前置依赖：阶段 1-4 已完成（Design System 全部令牌类型均已实现）
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

工程已有 \`CLAUDE.md\`（AI 编码助手指令）与 \`docs/architecture.md\`（架构文档），本阶段的文档更新需保持与现有风格一致。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程
- 单测：\`cd Packages/Utilities/DesignSystem && swift test\`


---

## 上文衔接

阶段 1-4 已完成 `DesignSystem` 包的全部能力建设：颜色（含深色模式）、字体字号、圆角、间距，以及可选的阴影和 UIKit 兼容层。目前已有部分页面完成替换验证。本阶段是收尾阶段，目标是全量迁移与文档沉淀。

## 本阶段目标

把现有各 Feature 包内散落的硬编码颜色/字体/圆角/间距值全部替换为 `DesignSystem` 的语义化令牌，并更新项目文档，让后续新增页面默认遵循规范。

## 需要实现的内容

### 1. 全量替换

- 逐个过一遍 `LoginFeature`、`ProductsFeature`、`BasketFeature`、`WebContainerFeature` 四个 Feature 包
- 全局搜索硬编码色值写法（如 `Color(red:green:blue:)`、`.foregroundColor(.blue)` 这类直接量），替换为 `DesignSystem` 的令牌引用
- 全局搜索硬编码字体写法（如 `.font(.system(size: 16))`），替换为字体令牌
- 全局搜索硬编码圆角/间距数值，替换为对应令牌

### 2. 文档更新

- 更新 `docs/architecture.md`：补充 `DesignSystem` 模块的架构说明（模块职责、目录位置、对外暴露的协议列表），风格与现有文档保持一致
- 更新 `CLAUDE.md`：加入明确约定，例如"新增 UI 时必须使用 DesignSystem 提供的颜色/字体/圆角/间距令牌，禁止硬编码具体数值"，方便后续用 Claude Code 开发新页面时自动遵循此规范，不需要每次都提醒

## 验收清单

- [ ] 全量搜索工程内硬编码色值写法，确认已收敛为个位数的合理例外（如确实需要一次性特殊效果的场景）或全部清零
- [ ] 全量搜索硬编码字体大小写法，同样收敛或清零
- [ ] `docs/architecture.md`、`CLAUDE.md` 均已更新
- [ ] 新增一个测试页面，验证不看文档也能通过补全提示自然使用到 `DesignSystem` 的令牌（说明 API 设计足够直观）

## 收尾说明

至此，全局 UI 设计规范系统（颜色/字体/圆角/间距，含深色模式支持）开发完成。如后续需要支持动态主题/换肤/服务端下发设计令牌，可以在现有协议基础上平滑扩展为 Abstraction/Domain/Data 四层结构（参考工程内 Weather、Routing 模块的先例），无需推翻现有调用方代码。

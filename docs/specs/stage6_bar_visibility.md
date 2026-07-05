# 阶段 6：导航栏 / TabBar 显示隐藏（重点保证丝滑）

> 前置依赖：阶段 1-5 已完成
> 说明：本文档为实施计划，不含具体代码实现

---

## 项目整体架构解析

项目采用 **Clean Architecture + SPM 模块化**，核心原则是严格的依赖倒置。

```
Presentation/Features  →  Domain  →  Abstraction  ←  Data
        │                                           ↑
        │                    ┌──────────────────────┘
        └──── Utilities ─────┘
```

本阶段实现主要落在 **Data 层**的 \`AppRouter\`，配合 **Abstraction 层**已定义的 \`RouteBarVisibilityConfiguration\`。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程


---

## 上文衔接

阶段 5 完成后，过渡动画（系统默认 + 自定义）已跑通，跳转体验已经具备基础的动画能力。本阶段要处理的是导航栏/TabBar 显示隐藏这类"跳转前后状态发生变化"的场景，重点是不能有跳变感。

## 本阶段目标

让 `RouteBarVisibilityConfiguration` 生效，且导航栏/TabBar 的显示隐藏切换与页面跳转动画完全同步。

## 需要实现的内容

在 `AppRouter` 中：

- **导航栏隐藏/显示**：结合 `transitionCoordinator`，在 push/pop 动画进行的同时同步执行 `setNavigationBarHidden(_:animated:)`，避免"先跳页面、栏后消失"的不同步问题
- **TabBar 隐藏/显示**：进入某些路由时隐藏 TabBar，返回上一页时按原页面的配置恢复显示，同样借助 `transitionCoordinator` 或动画完成回调保证同步
- **边界情况处理**：连续快速触发跳转（比如动画进行中再次点击跳转）时，需要有基本的防抖或状态保护，避免栏状态错乱、黑屏或卡死

## 验收清单

- [ ] 从"显示 TabBar 的页面"跳转到"隐藏 TabBar 的页面"，两者过渡在同一个动画时间线内完成，无闪烁
- [ ] 返回时 TabBar 能正确恢复显示
- [ ] 连续快速点击跳转/返回，不出现栏状态错乱、黑屏或崩溃
- [ ] 导航栏隐藏场景下，阶段 4 的统一导航栏 UI（如返回按钮）恢复显示时样式依然正确

## 下一阶段预告

阶段 7 将实现导航栏标题样式的可配置化，是路由功能 7 项需求中的最后一块。

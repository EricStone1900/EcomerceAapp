# 阶段 5：过渡动画 —— 系统默认 + 自定义

> 前置依赖：阶段 1-4 已完成（协议、编排、push/present、基类方案均已就绪）
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

| 层 | 职责 |
|---|---|
| **Abstraction** | 纯协议层，本阶段用到的 \`RouteTransition\`、\`RouteAnimatorProviding\` 都定义在这 |
| **Domain** | UseCase 业务编排 |
| **Data** | \`AppRouter\` 所在层，本阶段的动画实现落地在这里 |
| **Presentation** | SwiftUI Feature 包 |
| **Utilities** | \`PresentationCore\` 等横切工具 |
| **App 层** | 组合根 |

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程


---

## 上文衔接

阶段 4 完成后，`PresentationCore` 基类方案已落地，页面停留埋点与统一导航栏 UI 均已验证生效。跳转能力目前使用的是系统默认的 push/present 动画。

## 本阶段目标

让阶段 1 定义的 `RouteTransition` 真正生效，同时支持系统内置动画与外部自定义动画两条路径。

## 需要实现的内容

在 `RoutingData` 的 `AppRouter` 中：

- **系统动画分支**：
  - push 场景：默认已有 UIKit 原生 push 动画，确认 `RouteTransition.systemDefault` 与 `RouteTransition.system(...)` 两种取值都能正确映射
  - present 场景：对接 `modalTransitionStyle`（如 `.coverVertical`、`.crossDissolve`、`.flipHorizontal` 等系统内置样式）
- **自定义动画分支**：
  - 新增 `TransitioningCoordinator`（内部类，不对外暴露）
  - 承接 `UINavigationControllerDelegate.navigationController(_:animationControllerFor:from:to:)`，用于 push/pop 场景的自定义动画
  - 承接 `UIViewControllerTransitioningDelegate` 对应方法，用于 present/dismiss 场景的自定义动画
  - 把外部传入的 `RouteAnimatorProviding` 实现转换成实际的 `UIViewControllerAnimatedTransitioning` 对象返回给系统，调用方不需要碰路由框架内部代码即可注入自定义动画

## 建议提供的示例

实现至少一个自定义动画示例（比如一个简单的缩放淡入效果），作为后续业务方接入自定义动画的参考实现。

## 验收清单

- [ ] 至少验证 2 种系统内置动画效果（一种 push 系统效果、一种 present 系统效果）
- [ ] 提供至少一个自定义动画的示例实现，验证自定义动画路径可以正常跑通
- [ ] 动画期间无卡顿、无残影
- [ ] 自定义动画与阶段 4 的基类方案（埋点、统一导航栏 UI）不冲突，动画过程中埋点时机依然准确

## 下一阶段预告

阶段 6 将实现导航栏 / TabBar 的显示隐藏配置，重点是要与页面跳转动画同步，做到丝滑无跳变。

# 阶段 7：标题样式可配置

> 前置依赖：阶段 1-6 已完成
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

标题样式的默认统一设置在 \`PresentationCore\` 的 \`BaseNavigationController\` 里，单页面级别的覆盖在 \`BaseHostingController\` 里，两者分工配合。

## 如何使用现有工程

- \`xed .\` 打开工程，DEBUG 默认走 Mock API，无需后端即可跑通全流程


---

## 上文衔接

阶段 6 完成后，导航栏/TabBar 的显示隐藏已经能与跳转动画同步、无跳变。本阶段实现路由功能 7 项需求中的最后一项：标题样式可配置。

## 本阶段目标

让 `RouteTitleConfiguration` 生效，实现单页面粒度的标题样式覆盖，且不影响其他页面。

## 需要实现的内容

在 `BaseHostingController`（阶段 4 已建立）中：

- 基于 `UINavigationBarAppearance`（iOS 13+）在单个页面粒度覆盖标题的字体、颜色、对齐方式，不影响 `BaseNavigationController` 设置的全局默认样式
- 支持传入自定义 `titleView`（比如需要放 Logo 或搜索框的场景），与文本标题二选一
- 确保页面 `viewWillDisappear`/返回时，恢复上一页原本的导航栏样式配置，不产生污染

## 验收清单

- [ ] 至少验证一个自定义字体颜色的标题样式
- [ ] 验证一个自定义 `titleView` 的场景（如放置一个 Logo 图标）
- [ ] 页面返回后，上一页的导航栏样式没有被污染（样式作用域仅限当前页面）
- [ ] 未配置标题样式的页面，使用 `BaseNavigationController` 的全局默认样式，行为符合预期

## 下一阶段预告

阶段 8 将把现有 Feature（登录、商品、购物车、WebContainer）接入新路由，替换旧的跳转方式，做全量回归验证。

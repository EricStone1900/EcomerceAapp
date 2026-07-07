# 新增 ModuleTest Tab 页面

> 为 TabView 增加一个 ModuleTest Tab，用于集中展示/调用各功能组件入口

---

## Context

当前 TabView 有三个 Tab：Products、Basket、WebTest。需要新增第四个 Tab「ModuleTest」，页面是一个简单的列表，包含 5 个功能入口（占位），后续可扩展更多。

---

## 关键设计决策

1. **新建视图文件**：放在已有 `WebContainerFeature/DebugEntry/` 目录下（与 `WebTestEntryView`、`WebTestNativeProbeView`、`DesignSystemPreview` 同目录），因为 ModuleTest 属于测试/调试页面，复用该目录无需新建 SPM 包。
2. **不引入 ViewModel**：页面仅为静态列表，无需 ViewModel 或 Data/DI。
3. **Tab 样式**：参考 WebTest Tab 的 `NavigationStack` 包裹模式，为后续从列表 navigate 到详情页面预留导航能力。
4. **5 个功能入口**：纯文本占位，不跳转（`navigationDestination` 暂不添加）。

---

## 修改文件

### 1. `MyEcommerce/MyEcommerceApp.swift`

**a)** `Screen` 枚举新增 `.moduleTest` 值：

```swift
enum Screen {
    case Products
    case Basket
    case webTest
    case moduleTest
}
```

**b)** TabView 中新增 ModuleTest Tab（与 WebTest Tab 并列）：

```swift
NavigationStack {
    ModuleTestView()
        .navigationTitle("ModuleTest")
}
.tag(Screen.moduleTest)
.tabItem {
    Label("ModuleTest", systemImage: "square.stack.3d.up.fill")
}
```

---

## 新增文件

### `WebContainerFeature/Sources/WebContainerFeature/DebugEntry/ModuleTestView.swift`

```swift
import SwiftUI

/// ModuleTest 功能入口列表页。
///
/// 展示各功能组件的调用入口，后续可扩展为导航到具体演示页面。
public struct ModuleTestView: View {

    private let items: [ModuleTestItem] = [
        ModuleTestItem(title: "推送通知测试", subtitle: "测试本地推送功能"),
        ModuleTestItem(title: "文件下载测试", subtitle: "测试文件下载流程"),
        ModuleTestItem(title: "扫码功能测试", subtitle: "测试摄像头扫码"),
        ModuleTestItem(title: "定位服务测试", subtitle: "测试定位权限与获取"),
        ModuleTestItem(title: "网络状态测试", subtitle: "测试网络连通性"),
    ]

    public init() {}

    public var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.appBody)
                Text(item.subtitle)
                    .font(.appCaption)
                    .foregroundColor(.appTextSecondary)
            }
            .designPadding(.vertical, .s)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Item Model

private struct ModuleTestItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}
```

> 注：使用 DesignSystem 令牌（`.appBody`、`.appCaption`、`.appTextSecondary`），文件需 `import DesignSystem`。

---

## 验收清单

- [ ] `swift build` 可编译通过
- [ ] 登录后 TabView 出现 ModuleTest Tab
- [ ] ModuleTest 页面展示 5 个功能入口列表项
- [ ] Tab 切换正常工作
- [ ] 无新 SPM 包产生（复用 DebugEntry 目录）

---

## 验证方式

```bash
cd Packages/Utilities/DesignSystem && swift build
```

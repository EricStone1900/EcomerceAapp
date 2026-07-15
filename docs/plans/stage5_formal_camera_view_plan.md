# Stage 5：正式相机页面（阶段 C）

> Stage 1-4（`docs/plans/stage1_camera_core_plan.md` ~ `stage4_camera_plugin_preset_plan.md`）把渲染链、分析链、Vision 检测、插件生态+ Preset 全部实现并测试过，但除了 `MyEcommerce/Debug/CameraDebugView.swift` 这个手动验收用的调试页，没有一个真正面向最终用户的相机界面。本轮把 `CameraUI.CameraViewState`/`CameraAction`（Stage 4 落地的单向数据流契约）第一次接上真实的 View + ViewModel，交付一个可以从 App 里真正打开、使用的相机页面。

## C0：解决循环依赖——`CameraFeatureContext`/`ThermalObserver` 从 App 层搬进 `CameraFeature`

开始写 `CameraViewModel`时发现一个架构问题：`CameraViewModel` 必须产出 `CameraUI.CameraViewState`，所以只能住在 `CameraUI` 包（`CameraUI` 已经在 Stage 4 B3 加了对 `CameraFeature` 的依赖）；但它需要消费的 `CameraFeatureContext`/`ThermalObserver` 当时定义在 App target 的 `AppCameraComposition.swift` 里——`CameraUI` 作为一个 SPM 包无法 `import` App 可执行文件 target。

修法：把 `CameraFeatureContext`（纯数据契约）和 `ThermalObserver`（只依赖 `CameraPipeline`/`Foundation`，不需要知道 `CameraVision`/`CameraML`/`CameraFilters`）搬进 `Packages/Camera/CameraFeature/Sources/CameraFeature/CameraFeatureContext.swift`。`AppCameraComposition.swift`（App 层）现在只保留"用哪些具体插件类型装配"这部分逻辑（因为这部分必须 import CameraVision/CameraML/CameraFilters），装配完之后返回的还是 `CameraFeature.CameraFeatureContext`。

**副作用（好的）**：`ThermalObserver` 从完全无法验证的 App 层代码变成了 CLI 可测的 `CameraFeature` 代码——新增 2 条测试，用 `NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, ...)` 手动触发真实的通知路径（不是 mock），验证 post 一次通知能收到一次 `shouldForcePassthrough` 事件、以及 `stop()` 后 `start()` 重新订阅依然工作。跳过了"证明 stop() 之后不会再收到事件"这类需要竞态/超时断言的用例——跟 `CameraVision.HorizonAnalyzer` 当初跳过"空结果"用例是同一个理由，写一个可能偶发失败的脆弱测试不如不写。

## C1：`CameraViewModel`（住在 `CameraUI`，不是 `CameraFeature`）

`Packages/Camera/CameraUI/Sources/CameraUI/ViewModel/CameraViewModel.swift`——`@MainActor final class CameraViewModel: ObservableObject`：

- `@Published private(set) var state: CameraViewState?`——`nil` 直到第一个 `DeviceCapability` 到达（`CameraViewState.capability` 是必填字段，没有可以诚实填充的默认曝光范围，不伪造一份假的能力范围）。
- `send(_ action: CameraAction) async`：`setISO`/`setShutter`/`setEV`/`setWB`/`focus`/`switchLens` 直接转发给 `context.session.apply(_:)`；`applyPreset` 调 `context.presetUseCase.apply(...)`，用返回的 `processorCount` 决定 `previewMode` 是 `.passthrough` 还是 `.processed`（Stage 2 定义的规则）；`capture` 调 `context.documentCaptureUseCase.capture(...)`。
- 复用了 `CameraDebugViewModel`（App 层调试页）里已经验证过的两个模式：`PreviewLayerFrameProvider`（每批 annotations 到达时现读 `previewLayer.frame`，不缓存陈旧快照）、`OverlayManager` 坐标转换。
- 订阅 `context.thermalObserver.shouldForcePassthrough`，收到 `true` 就强制把 `previewMode` 拉回 `.passthrough`——热降级第一次真正影响到 UI 层。

**无法 CLI 验证**（`CameraUI` 只声明 `platforms: [.iOS(.v18)]`，从来没有 macOS 支持），但它调用的每一个 UseCase（`CameraSessionUseCase`/`PresetUseCase`/`DocumentCaptureUseCase`/`ThermalPolicyUseCase`/`ThermalObserver`）都已经在 `CameraFeature` 测过——这里的"未测试面"被刻意压缩到只剩接线本身，不是业务逻辑。

## C2：`CameraView`

`Packages/Camera/CameraUI/Sources/CameraUI/CameraView.swift`：

- 预览区复用 Stage 1/2 的 `PassthroughPreviewContainer`/`ProcessedPreviewContainer` + `OverlayCanvas`，`state == nil` 时显示 `ProgressView` 而不是假装有一份能用的手动控制面板。
- 底部 `CameraControlPanel`（拆成独立子视图，避免 `state` 变化时整个预览层级跟着重新求值）：镜头切换（segmented）、Preset 选择（menu，`Manual`/`Document`/`Portrait`/`Food`/`Night`）、ISO/EV 滑杆（范围来自 `state.capability.isoRange`/`evRange`，不是硬编码）、拍照按钮。
- 用了真实的 `DesignSystem` token（`CameraUI/Package.swift` 新增对 `Packages/Utilities/DesignSystem` 的依赖——Camera 子系统此前 8 轮迭代都没有用过 DesignSystem，这是第一次接入）。写的时候第一版猜了一个不存在的 API（`.designSpacing(.m)`），读了 `DesignSystem/View+Padding.swift` 源码确认真实 API 是 `CGFloat.spacingM` 之后改对——记录这个是提醒自己别对 DesignSystem 的具体 API 形状想当然。

## C3：接入 App

**跟原计划"路由接入"这一步不一样**：计划里设想的是走 `RoutingAbstraction`/`RoutingData` 那套新路由系统（`CameraRoute` + `CameraRouteFactory`，仿照 `ProductRouteFactory`）。实际去读了 `AppRouteFactoryRegistrar.swift` 和其他 Feature 的接入方式才发现：**这套新路由系统目前没有被任何一个 Feature 真正调用过**——`NavigateUseCase`/`RouterProtocol.navigate(to:configuration:)` 存在且注册了，但没有任何 ViewModel 实际调用它；现有 5 个 tab（Products/Basket/WebTest/ModuleTest/CameraTest）全部是直接把 View 嵌进 `TabView`，不经过路由系统。`ModuleTestView` 本身也是纯静态列表，连它现有的 5 个占位项都没有接任何导航。

在这个前提下，跟着计划抄 `CameraRoute`/`CameraRouteFactory` 会引入一段没有真实调用方的死代码，也不符合"从 ModuleTest 加入口"这个当初设想（ModuleTestView 现在还没有任何真正可用的导航基础设施）。改成跟 `CameraDebugView` 完全一样的既有模式：`MyEcommerceApp.swift` 新增一个 `Screen.camera` tab，直接内嵌一个新的 `CameraTabContent`（小容器 View，用 `@State` 保证 `AppCameraComposition.makeCameraFeature()` 只在这个 tab 第一次出现时构造一次，不会跟着 `MyEcommerceApp.body` 的其它状态变化重复构造）。`CameraDebugView` 所在的 "CameraTest" tab 保留不动，新 "Camera" tab 是独立的正式入口。

## Xcode 编译报错修复（真机验收时发现）

用户在 Xcode 里编译 `AppCameraComposition.swift`（当时还在 App 层持有 `ThermalObserver` 定义）时报错：`Sending main actor-isolated 'self.thermalPolicyUseCase' to nonisolated instance method 'handle' risks causing data races`。根因：`ThermalPolicyUseCase`/`PresetUseCase`/`DocumentCaptureUseCase` 都是普通 struct，存储属性全是 Sendable 安全的（actor + `any CameraSourceProtocol` 因为协议本身 `: Actor`），但没有显式声明 `: Sendable`——Swift 对 public 类型的隐式 Sendable 推导不保证跨模块可靠传播。给三个 UseCase 都补上显式 `Sendable` conformance 后解决（一次性修三个，不是只修报错的那一个，因为另外两个是完全一样的结构，迟早会在类似的跨 actor 调用场景里撞上同一个错误）。详见 `stage4_camera_plugin_preset_plan.md` 对应章节。

## 验证结果

```
=== Shared ===        12 tests passed
=== CameraCore ===    5 tests passed
=== CameraPipeline === 13 tests passed
=== CameraVision ===  9 tests passed
=== CameraFeature === 30 tests passed（本轮新增 ThermalObserver 2 条）
=== CameraFilters ===  11 tests passed
=== CameraML ===       2 tests passed
```

## 仍未完成 / 仍未验证

1. `CameraView`/`CameraViewModel`/`CameraTabContent`/`MyEcommerceApp.swift` 的改动全部无法 CLI 验证，只做了人工代码走查，需要真机/Xcode 验收：新 "Camera" tab 能否正常打开、预览画面是否正常显示、镜头切换/Preset 应用/ISO-EV 滑杆/拍照按钮是否都能正确驱动状态、热降级真的触发时预览是否会被强制拉回 passthrough。
2. `CameraView.Package.swift` 新增了对 `DesignSystem` 的依赖——这是 Camera 子系统第一次跟主 App 的 Utilities 包产生连接，Xcode target 是否需要额外链接步骤未知（沿用一贯的传递解析假设，但没有实测过 `DesignSystem` 这条路径）。
3. `AppCameraComposition.swift` 里 `YOLO.mlmodelc`/`Food.cube` 两个资产文件仍然没有添加到 Xcode target（Stage 4 B4 就已经记录的已知限制，本轮没有变化）。
4. `CameraPreset` 目前只有 4 个写死的内置 Preset（`.document`/`.portrait`/`.food`/`.night`），没有持久化/自定义 Preset 的 UI，也没有 `CapabilityValidator.clamp` 触发时的 UI 提示（Stage 4 设计概要提到"校验失败降级而非报错，同时上报 UI 提示"——降级本身实现了，UI 提示没有）。
5. 拍照结果（`CameraViewModel.lastDocumentCapture`）目前没有在 `CameraView` 里展示任何预览或反馈——`CameraDebugView` 有一个简单的图片预览，`CameraView` 目前拍完照片之后 UI 上没有任何可见变化，只是状态被更新了。

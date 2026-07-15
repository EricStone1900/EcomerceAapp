# iOS 专业相机项目架构 V2（V1 + V4 + V5）

> 修订版。相对初版的核心变更：
> 1. 预览拆分为 Passthrough / Processed 双模式，解决"PreviewLayer 与 Pipeline 输出互斥"矛盾
> 2. Pipeline 拆分为 **渲染链（同步）+ 分析链（异步）**，ML 慢不拖累预览帧率
> 3. 新增 `Frame` 统一帧模型与零拷贝内存策略
> 4. 新增 `DeviceCapability` 设备能力层，Preset 应用前 clamp
> 5. 拍照改为 RAW/Processed 双轨落盘
> 6. 明确组合根（Composition Root）与插件注册机制，UI 层零算法依赖

---

## 1. 目标功能

| 版本 | 功能 |
|---|---|
| **V1 基础专业相机** | 手动 ISO / 快门 / 曝光补偿 / 白平衡 / 手动对焦、RAW(DNG)、Histogram、Grid / Level、多镜头切换 |
| **V4 计算摄影** | 文档检测、卡片检测、自动裁剪 |
| **V5 可扩展能力** | CoreML 插件、滤镜插件、Preset 相机预设 |

---

## 2. 分层总览

自下而上，**依赖只允许向下**，同层横向不依赖：

```text
┌─────────────────────────────────────────────────┐
│ App (组合根)                                     │  L5 组装层
│   PluginRegistry / DI / Preset 装配              │
├─────────────────────────────────────────────────┤
│ CameraFeature                                    │  L4 业务编排层
│   拍摄流程用例 / 状态机 / Preset 应用             │
├─────────────────────────────────────────────────┤
│ CameraUI                                         │  L4 展示层
│   SwiftUI 控件 / Overlay 渲染 / Preview 容器      │
├─────────────────────────────────────────────────┤
│ CameraVision │ CameraML │ CameraFilters          │  L3 插件实现层
│   (全部实现 L2 定义的插件协议)                    │
├─────────────────────────────────────────────────┤
│ CameraPipeline                                   │  L2 帧处理层
│   Frame 模型 / 渲染链 / 分析链 / 插件协议          │
├─────────────────────────────────────────────────┤
│ CameraCore                                       │  L1 采集层
│   AVCaptureSession / 设备控制 / Capability        │
├─────────────────────────────────────────────────┤
│ Shared                                           │  L0 基础层
│   通用类型 / 日志 / 坐标转换 / 几何工具            │
└─────────────────────────────────────────────────┘
```

**关键依赖规则**（SPM 强制约束）：

```text
CameraUI        依赖 CameraPipeline(仅协议与模型), Shared
CameraUI        禁止依赖 CameraVision / CameraML / CameraFilters
CameraVision/ML/Filters 依赖 CameraPipeline(协议), Shared
CameraVision/ML/Filters 禁止依赖 CameraCore / CameraUI
CameraCore      仅依赖 Shared，不知道任何插件的存在
CameraFeature   依赖 CameraCore, CameraPipeline, CameraPreset（不依赖具体插件包）
App             依赖所有包 —— 唯一知道全貌的地方
```

> 扩展性来源于此：新增一个 ML 模型 / 滤镜 = 新增一个实现 L2 协议的类型 + 在 App 组合根注册一行。**L1/L2/L4 零改动。**

---

## 3. L0 Shared

- `CameraError`、`Logger`
- **`CoordinateConverter`**：统一处理 Vision 归一化坐标(左下原点) → 预览层 UIKit 坐标，封装 rotation / mirror / videoGravity 裁切偏移。所有 Overlay 只用这一个服务转换，禁止各自实现
- `GeometryUtils`：四边形透视校正矩阵、EMA/低通滤波（检测框时域平滑用）

---

## 4. L1 CameraCore（纯采集，actor 隔离）

### 4.1 职责

- AVCaptureSession 生命周期（专用 sessionQueue，对外暴露为 `actor CameraSession`）
- 设备控制：Focus / Exposure(ISO+Duration) / WB / Zoom / Torch / 镜头切换
- 输出：`AVCapturePhotoOutput`（RAW+Processed）、`AVCaptureVideoDataOutput`、`AVCaptureMovieFileOutput`
- 中断与恢复：来电 / 分屏 / `sessionRuntimeError` / 权限流程
- 热管理：监听 `thermalStateDidChange`，向上抛事件（降级策略由 Feature 层决定）

### 4.2 DeviceCapability（新增，V1 必须）

每颗镜头能力不同，手动控制与 Preset 都依赖它：

```swift
public struct DeviceCapability: Sendable {
    public let lens: LensType                    // wide / ultraWide / tele
    public let isoRange: ClosedRange<Float>
    public let shutterRange: ClosedRange<CMTime>
    public let evRange: ClosedRange<Float>
    public let wbGainsRange: WBGainsRange
    public let supportsRAW: Bool
    public let supportsProRAW: Bool
    public let maxZoomFactor: CGFloat
    public let supportedFormats: [CaptureFormatDescriptor]
}
```

- 切换镜头时发布新的 Capability，UI 据此重建滑杆范围
- **镜头策略：物理设备 + 手动切换**（专业相机取舍：虚拟设备无缝变焦但限制手动控制）

### 4.3 可测试性

```swift
protocol CaptureSessionProviding { ... }   // 真机: AVCaptureSession；测试: 帧回放器
```

Pipeline / Vision / ML 的所有单测通过注入录制帧序列完成，不依赖真机。

### 4.4 对外接口（唯一出口）

```swift
public protocol CameraSourceProtocol: Actor {
    var frames: AsyncStream<Frame> { get }          // 供 Pipeline 消费
    var capability: AsyncStream<DeviceCapability> { get }
    var previewLayer: AVCaptureVideoPreviewLayer { get } // 仅 Passthrough 模式使用
    func apply(_ control: CameraControl) async throws    // 统一控制指令
    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult
}
```

---

## 5. L2 CameraPipeline（帧处理中枢）

### 5.1 Frame：全 pipeline 统一货币

```swift
public struct Frame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer   // IOSurface-backed
    public let timestamp: CMTime
    public let orientation: CGImagePropertyOrientation
    public let cameraMetadata: FrameMetadata // 曝光/镜头/intrinsics
}
```

**内存铁律**：
- camera buffer 池仅 ~15 个，任何异步插件**禁止持有 CMSampleBuffer**；Frame 只 retain CVPixelBuffer
- 分析链拿到 Frame 后应尽快提取所需数据并释放
- Metal 侧通过 `CVMetalTextureCache` 零拷贝取纹理，禁止 CIImage ↔ UIImage 往返

### 5.2 双链模型（本次修订核心）

```text
                       ┌──────────── 渲染链（同步，每帧，GPU）────────────┐
Frame ──┬─────────────▶│ FrameProcessor: Filter → LUT → Beauty          │──▶ MTLTexture ──▶ ProcessedPreview
        │              └────────────────────────────────────────────────┘
        │
        │ 丢帧采样(latest-wins, 5~15fps)
        └─────────────▶┌──────────── 分析链（异步，可并行）───────────────┐
                       │ FrameAnalyzer: Document / CoreML / Histogram    │──▶ AsyncStream<[Annotation]> ──▶ OverlayManager
                       └────────────────────────────────────────────────┘
```

两个插件协议，特性彻底分离：

```swift
/// 渲染类：同步、必须每帧、只做 GPU 操作，禁止阻塞
public protocol FrameProcessor: Sendable {
    var id: PluginID { get }
    func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture
}

/// 分析类：异步、可丢帧，产出元数据而非修改帧
public protocol FrameAnalyzer: Sendable {
    var id: PluginID { get }
    var preferredFPS: Int { get }                // 各插件独立采样率
    func analyze(_ frame: Frame) async -> [Annotation]
}
```

分析链调度：**latest-frame-wins** —— 新帧到达时若上一个任务未完成则丢弃新帧（或取消旧任务），保证不积压、不 OOM。

### 5.3 Annotation：分析结果的统一模型

```swift
public enum Annotation: Sendable {
    case quad(id: UUID, corners: [CGPoint], confidence: Float)  // 文档/卡片，归一化坐标
    case histogram(HistogramData)
    case objects([DetectedObject])
    case horizon(angle: Double)
    case custom(key: String, payload: any Sendable)             // V5 扩展口
}
```

- Annotation 统一携带**归一化坐标**，转换到屏幕坐标是 OverlayManager 的事（用 Shared.CoordinateConverter）
- quad 类结果在 OverlayManager 内做 EMA 时域平滑，消除抖动

### 5.4 PipelineController

```swift
public actor PipelineController {
    func setProcessors(_ ps: [any FrameProcessor])   // 运行时可增删（Preset 切换）
    func setAnalyzers(_ as: [any FrameAnalyzer])
    var annotations: AsyncStream<[Annotation]> { get }
    var renderedFrames: AsyncStream<MTLTexture> { get } // 供 ProcessedPreview / 录像 Writer
}
```

---

## 6. 预览双模式（解决初版矛盾）

| 模式 | 载体 | 使用场景 | 功耗 |
|---|---|---|---|
| **PassthroughPreview** | `AVCaptureVideoPreviewLayer` | V1 纯手动、无滤镜 | 最低 |
| **ProcessedPreview** | `MTKView` / `CAMetalLayer` 渲染 pipeline 输出 | 有任一 FrameProcessor 激活时 | GPU 常驻 |

- 切换规则：`processors.isEmpty ? .passthrough : .processed`，由 Feature 层自动决定，UI 不感知
- 两种模式下 Overlay 均为独立图层叠加在预览之上，与预览实现解耦
- 热降级：thermal serious 时 Feature 层可强制回落 passthrough + 暂停分析链

---

## 7. L3 插件实现层

### CameraVision（基于 Vision framework 的 Analyzer 集合）

`DocumentAnalyzer` / `CardAnalyzer` / `RectangleAnalyzer` / `OCRAnalyzer` / `BarcodeAnalyzer` / `FaceAnalyzer` / `HorizonAnalyzer` —— 全部实现 `FrameAnalyzer`。

### CameraML（CoreML 插件容器）

```swift
public protocol MLModelPlugin: FrameAnalyzer {
    associatedtype Input
    associatedtype Output
    var model: MLModel { get }
    func preprocess(_ frame: Frame) -> Input
    func postprocess(_ output: Output) -> [Annotation]
}
```

- 模型加载惰性化 + 可卸载（内存压力时 Feature 层触发卸载）
- YOLO / Pose / Food 等 = 一个类型 + 组合根一行注册

### CameraFilters（Processor 集合）

`CIFilterProcessor` / `LUTProcessor`（.cube 解析 + 3D 纹理采样）/ `MetalShaderProcessor` / `BeautyProcessor` —— 全部实现 `FrameProcessor`，内部统一走 Metal，CIFilter 用共享 `CIContext(mtlDevice:)`。

---

## 8. CameraPreset

```swift
public struct CameraPreset: Codable, Sendable {
    public var name: String
    public var lens: LensType
    public var manual: ManualSettings?        // ISO/Shutter/EV/WB，nil = 自动
    public var processorIDs: [PluginID]       // 只存 ID，不存实例
    public var analyzerIDs: [PluginID]
    public var captureFormat: CaptureFormat   // raw / heif / rawPlusHeif
}
```

**应用流程（含 clamp）**：

```text
Preset ──▶ CapabilityValidator.clamp(preset, capability)   // ISO 3200 在超广角上收敛到合法值
       ──▶ CameraCore.apply(controls)
       ──▶ PluginRegistry.resolve(ids) ──▶ Pipeline.setProcessors/Analyzers
```

内置：Document（DocumentAnalyzer + 自动裁剪开）/ Portrait / Food / Night。校验失败降级而非报错，同时上报 UI 提示。

---

## 9. L4 CameraUI（零算法依赖）

### 9.1 耦合控制手段

1. **只依赖 CameraPipeline 的协议与模型**（Annotation / Frame / DeviceCapability），编译期就不可能 import CameraML
2. **单向数据流**：UI 订阅 `CameraViewState`，发送 `CameraAction`，不直接触碰 CameraCore

```swift
public struct CameraViewState: Sendable {
    public var capability: DeviceCapability
    public var manual: ManualSettings
    public var annotations: [ScreenAnnotation]   // 已转换为屏幕坐标
    public var previewMode: PreviewMode
    public var activePreset: PresetID?
}

public enum CameraAction: Sendable {
    case setISO(Float), setShutter(CMTime), setEV(Float), setWB(WBGains)
    case focus(at: CGPoint), switchLens(LensType)
    case applyPreset(PresetID), capture
}
```

3. **Overlay 声明式渲染**：OverlayManager 把 `[Annotation]` 转成 `[ScreenAnnotation]`，SwiftUI 端仅是 `ForEach + Canvas` 按类型画图，新增 Annotation 类型只需加一个绘制 case，不需要 UI 知道数据从哪来

### 9.2 结构

```text
CameraScreen (SwiftUI)
 ├── PreviewContainer (UIViewRepresentable: PreviewLayer 或 MTKView，唯一 UIKit 点)
 ├── OverlayCanvas   (SwiftUI Canvas，画 grid/level/histogram/检测框)
 ├── ManualControlBar (滑杆范围绑定 capability)
 └── PresetShelf
```

---

## 10. L4 CameraFeature（业务编排）

- `CameraSessionUseCase`：启动/权限/中断恢复状态机
- `CapturePhotoUseCase`：**双轨落盘** —— DNG 原样保存（不 crop 不 filter），并行产出应用了 crop/filter/preset 的 HEIF/JPEG；EXIF 写入拍摄参数/镜头/GPS
- `DocumentCaptureUseCase`：quad Annotation → 透视校正 → 自动裁剪（V4）
- `ThermalPolicyUseCase`：serious → 分析链降频；critical → 停分析链 + 回落 passthrough
- `PresetUseCase`：clamp → apply → 装配插件

---

## 11. App 组合根（唯一装配点）

```swift
// App 是唯一 import 全部包的地方
let registry = PluginRegistry()
registry.register(LUTProcessor.self, id: .lut)
registry.register(DocumentAnalyzer(), id: .document)
registry.register(YOLOPlugin(),      id: .yolo)        // ← 新增能力只加这一行

let camera   = CameraSession()
let pipeline = PipelineController()
let feature  = CameraFeature(camera: camera, pipeline: pipeline,
                             registry: registry, presets: PresetStore())
```

与 EcommerceAppDemo 中 `AppWebRouteFactory` 同一模式：**协议在低层包定义，实现分散在插件包，装配只发生在 App。**

---

## 12. 数据流总览

```text
【预览】 Camera ─Frame─▶ Pipeline ─┬─渲染链─▶ MTLTexture ─▶ ProcessedPreview
                                   └─分析链─▶ Annotations ─▶ Overlay
【拍照】 capture ─▶ ┬─ DNG 原样落盘（保留全部信息）
                    └─ Processed: crop → filter → HEIF + EXIF ─▶ PhotoLibrary
【视频】 renderedFrames ─▶ AVAssetWriter（与预览共用渲染链输出，零重复计算）
```

---

## 13. 分阶段交付

### Stage 1 — CameraCore + Passthrough 预览（V1 前半）
Session 生命周期 / 手动 ISO·快门·EV·WB·对焦 / DeviceCapability / 镜头切换 / 中断恢复 / CaptureSessionProviding 测试桩

**验收**：
- [ ] 三颗镜头切换后滑杆范围随 capability 更新
- [ ] 来电中断后自动恢复预览
- [ ] 手动参数在锁屏-解锁后保持
- [ ] 帧回放器可驱动 Pipeline 单测（无真机）

### Stage 2 — Pipeline 双链 + Overlay（V1 后半）
Frame 模型 / 渲染链 Metal 通路 / 分析链 latest-wins 调度 / HistogramAnalyzer / Grid·Level Overlay / CoordinateConverter

**验收**：
- [ ] 空渲染链时预览稳定 30/60fps
- [ ] Histogram 开启不影响预览帧率（分析链独立采样）
- [ ] 旋转/镜像下 Overlay 与画面严格对齐
- [ ] RAW(DNG) + HEIF 双轨落盘，EXIF 完整

### Stage 3 — Vision + 自动裁剪（V4）
DocumentAnalyzer / CardAnalyzer / quad 时域平滑 / 透视校正 / DocumentCaptureUseCase

**验收**：
- [ ] 检测框无可见抖动（EMA 生效）
- [ ] 拍照输出裁剪校正件 + 原始 DNG 两份
- [ ] 关闭检测后分析链零 CPU 占用

### Stage 4 — 插件生态 + Preset（V5）
MLModelPlugin 协议 / LUTProcessor / PluginRegistry / Preset clamp·持久化 / ProcessedPreview 自动切换 / 热降级策略

**验收**：
- [ ] 新增一个 CoreML 模型仅需新类型 + 注册一行，CameraUI 零改动
- [ ] Preset 跨镜头应用时非法参数被 clamp 且 UI 提示
- [ ] thermal critical 时自动回落 passthrough
- [ ] 实时 LUT 下预览 ≥30fps（A15 及以上）

---

## 14. 本版架构如何满足三条要求

| 要求 | 落点 |
|---|---|
| **分层合理** | 采集(L1)/处理(L2)/算法(L3)/编排+展示(L4)/装配(L5) 单向依赖；渲染与分析按实时性拆链；能力(Capability)与配置(Preset)分离 |
| **易扩展** | 新算法 = 实现 FrameProcessor/FrameAnalyzer + 组合根注册一行；Annotation.custom 兜底未知类型；Preset 只存 PluginID 与实例解耦 |
| **UI 低耦合** | UI 只 import Pipeline 协议包（编译期隔离）；单向 State/Action 流；Overlay 吃 ScreenAnnotation 声明式绘制；预览模式切换对 UI 透明 |

# Stage 2：Pipeline 双链 + Overlay（V1 后半）

> 专业相机架构第二阶段：在 Stage 1 的 CameraCore 之上接入 CameraPipeline，把"渲染（同步/每帧/GPU）"和"分析（异步/可丢帧）"拆成两条独立链路，让 ML/检测类工作慢不拖累预览帧率；同时接入 Overlay 图层与 RAW+HEIF 双轨落盘拍照。

来源文档：`docs/specs/iOS_Professional_Camera_Architecture_V2.md` 第 4.1（AVCapturePhotoOutput RAW+Processed）、5、6、9.1/9.2（Overlay 部分）、10（CapturePhotoUseCase）、13（Stage 2）节。

## 背景

Stage 1 交付了 CameraCore + Passthrough 预览，画面能看但无法叠加任何处理或检测结果。本 stage 引入 L2 `CameraPipeline`，定义全 pipeline 统一的 `Frame` 模型、双链调度模型、`FrameProcessor`/`FrameAnalyzer` 两个插件协议，并把第一个内建分析器（Histogram）接进去验证链路。完成后，预览可以在 Passthrough 与 Processed 两种模式间无感切换，且能看到 Overlay（Grid/Level/Histogram）。

## 设计概要

- 分层依赖规则（本 stage 相关部分）：
  - `CameraPipeline` 依赖 `Shared`，不依赖 `CameraCore`（Pipeline 只认 `Frame`，不知道 Frame 是怎么采集出来的）
  - `CameraUI` 依赖 `CameraPipeline`（仅协议与模型：`Annotation`、`Frame`）+ `Shared`，**禁止**依赖 `CameraVision`/`CameraML`/`CameraFilters`
- **内存铁律**（贯穿本 stage 所有实现）：camera buffer 池仅 ~15 个，任何异步插件禁止持有 `CMSampleBuffer`，`Frame` 只 retain `CVPixelBuffer`；分析链拿到 Frame 后应尽快提取所需数据并释放；Metal 侧通过 `CVMetalTextureCache` 零拷贝取纹理，禁止 CIImage ↔ UIImage 往返。
- **双链模型**：渲染链同步执行于每一帧（`FrameProcessor: process(texture:context:) -> MTLTexture`，禁止阻塞）；分析链异步执行、latest-frame-wins 调度——新帧到达时若上一个分析任务未完成，直接丢弃新帧（或取消旧任务），保证不积压、不 OOM。
- **预览双模式切换规则**：`processors.isEmpty ? .passthrough : .processed`，由 Feature 层自动决定，UI 不感知；两种模式下 Overlay 均为独立图层叠加在预览之上，与预览实现解耦。热降级：thermal serious 时 Feature 层可强制回落 passthrough + 暂停分析链（策略本体在 Stage 4 `ThermalPolicyUseCase`，本 stage 只需预留 hook）。
- **设计决策（原文档未细化，本 stage 补充）**：Stage 2 验收要求的 `HistogramAnalyzer` 不依赖 Vision framework，属于内建分析器，因此实现放在 `CameraPipeline` 包内部而不是新开 `CameraVision`（`CameraVision` 从 Stage 3 才创建，专门收纳基于 Vision framework 的分析器）。

**实现期修正（相对本文档早期草稿）**：
1. `CameraPipeline` 实际**不依赖 `Shared`**——早期草稿写了"CameraPipeline 依赖 Shared"，但 Stage 2 落地的所有类型（`Frame`/`FrameMetadata`/`Annotation`/`FrameProcessor`/`FrameAnalyzer`/`PipelineController`/`HistogramAnalyzer`）都不需要 `LensType`/`CameraError`/`CoordinateConverter`/`GeometryUtils` 里的任何一个，加这个依赖是无用的（`GeometryUtils.EMAFilter` 真正被用到是在 Stage 3 的 `OverlayManager` 里，那是 `CameraUI` 依赖 `Shared`，不是 `CameraPipeline`）。`CameraPipeline` 目前是完全自包含的包，只依赖系统 framework（CoreMedia/CoreVideo/ImageIO/simd/Metal/Accelerate）。
2. `PipelineController.annotations`/`renderedFrames` 原本写成"每次访问属性都新建一条 `AsyncStream`"，和 Stage 1 `CameraSession.frames`/`capability` 犯的是同一个错误——多个消费者会互相看不到彼此、且没有任何生产者持有 continuation。修正为：两个 stream 和它们的 continuation 都在 `init` 里一次性创建好，`annotationContinuation`/`renderedFrameContinuation` 存成私有的 actor-isolated 属性（只在 `consume` 内部用，不需要 nonisolated）。
3. `AsyncStream<[Annotation]>` 是真正 Sendable 的（`Annotation: Sendable`），所以 `public nonisolated let annotations` 不需要 `unsafe`；但 `AsyncStream<MTLTexture>` 不是 Sendable（`MTLTexture` 协议未被 Metal 标注 Sendable），`renderedFrames` 需要 `nonisolated(unsafe)`（原因同 Stage 1 `CameraSession.previewLayer`）。
4. `RenderContext` 持有 `MTLDevice`/`MTLCommandBuffer`（都不是 Sendable），声明成 `@unchecked Sendable`（和 `Frame` 用 `@unchecked Sendable` 是同一个理由：每帧只读传递，不会被并发修改）。
5. `PipelineController.consume(...)` 里 `renderedFrameContinuation.yield(output)` 编译报错 `sending 'output' risks causing data races`——`AsyncStream.Continuation.yield(_:)` 的参数是 `sending Element`，把非 Sendable 的 `MTLTexture` 从 actor 隔离域"送出"会被 Swift 6 拦下来。修正：在 `PipelineController.swift`、`FrameProcessor.swift`（凡是签名里出现 `MTLTexture`/`MTLDevice`/`MTLCommandBuffer` 的文件）用 `@preconcurrency import Metal` 代替普通 `import Metal`——这是 Apple 自己推荐的处理"未审计 Sendable 的系统 framework"的标准写法，不需要为此把公开的 `AsyncStream<MTLTexture>` 类型换成自定义包装类型。调用方（测试文件、`CameraUI.ProcessedPreviewContainer`）只要把同一个非 Sendable 类型传进/传出 actor 边界，也要在各自文件顶部加同样的 `@preconcurrency import Metal`。
6. `CameraSession.capturePhoto(_:)`（Stage 1 只会 `throw CameraError.captureFailed`）现在改为直接 `try await captureDualTrack(request)`——`captureDualTrack` 本身在 Stage 2 仍是占位实现（真正的 `AVCapturePhotoOutput` RAW+HEIF 委托桥接还没写），但至少把公开入口和内部实现接起来，不是两个互不relate的死代码。

## 新增文件

```
Packages/Camera/CameraPipeline/
├── Package.swift
├── Sources/CameraPipeline/
│   ├── Model/
│   │   ├── Frame.swift
│   │   ├── FrameMetadata.swift
│   │   └── Annotation.swift
│   ├── Protocol/
│   │   ├── FrameProcessor.swift
│   │   └── FrameAnalyzer.swift
│   ├── PipelineController.swift
│   └── Analyzer/
│       └── HistogramAnalyzer.swift
└── Tests/CameraPipelineTests/
    ├── PipelineControllerLatestWinsTests.swift
    └── HistogramAnalyzerTests.swift

Packages/Camera/CameraUI/Sources/CameraUI/
├── Preview/
│   └── ProcessedPreviewContainer.swift   // MTKView / CAMetalLayer 渲染 pipeline 输出
├── Overlay/
│   ├── OverlayCanvas.swift
│   └── ScreenAnnotation.swift
├── PreviewMode.swift
└── State/
    └── CameraViewState.swift             // 修改：替换 Stage 1 占位字段，补 annotations

Packages/Camera/CameraCore/Sources/CameraCore/
└── CapturePhoto+DualTrack.swift          // RAW+Processed 双轨落盘扩展 CameraSession
```

### `CameraPipeline/Sources/CameraPipeline/Model/Frame.swift`

```swift
import CoreMedia
import CoreVideo
import ImageIO

/// 全 pipeline 统一货币。camera buffer 池仅 ~15 个，Frame 只 retain CVPixelBuffer，
/// 任何异步插件禁止持有 CMSampleBuffer。
public struct Frame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer   // IOSurface-backed
    public let timestamp: CMTime
    public let orientation: CGImagePropertyOrientation
    public let cameraMetadata: FrameMetadata

    public init(pixelBuffer: CVPixelBuffer, timestamp: CMTime, orientation: CGImagePropertyOrientation, cameraMetadata: FrameMetadata) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.orientation = orientation
        self.cameraMetadata = cameraMetadata
    }
}
```

### `CameraPipeline/Sources/CameraPipeline/Model/FrameMetadata.swift`

```swift
import CoreMedia

public struct FrameMetadata: Sendable {
    public let iso: Float
    public let shutterDuration: CMTime
    public let lensPosition: Float
    public let intrinsics: simd_float3x3?
}
```

### `CameraPipeline/Sources/CameraPipeline/Model/Annotation.swift`

```swift
import CoreGraphics

/// 分析结果的统一模型。统一携带归一化坐标，转换到屏幕坐标是 OverlayManager 的事
/// （用 Shared.CoordinateConverter）。quad 类结果在 OverlayManager 内做 EMA 时域平滑，消除抖动。
public enum Annotation: Sendable {
    case quad(id: UUID, corners: [CGPoint], confidence: Float)  // 文档/卡片，Stage 3 接入
    case histogram(HistogramData)
    case objects([DetectedObject])
    case horizon(angle: Double)
    case custom(key: String, payload: any Sendable)             // V5 扩展口
}

public struct HistogramData: Sendable {
    public let redBuckets: [Float]
    public let greenBuckets: [Float]
    public let blueBuckets: [Float]
    public let luminanceBuckets: [Float]
}

public struct DetectedObject: Sendable {
    public let label: String
    public let boundingBox: CGRect
    public let confidence: Float
}
```

### `CameraPipeline/Sources/CameraPipeline/Protocol/FrameProcessor.swift` / `FrameAnalyzer.swift`

```swift
// 见 PipelineController.swift 顶部注释：Metal 协议类型未标注 Sendable，用 @preconcurrency 处理。
@preconcurrency import Metal

public struct PluginID: Hashable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

// MTLDevice/MTLCommandBuffer 是 Objective-C 协议类型，Metal 框架没有把它们标记为 Sendable，
// 但 RenderContext 只是每帧只读传递的值，不会被并发修改，用 @unchecked Sendable 显式声明安全。
public struct RenderContext: @unchecked Sendable {
    public let device: MTLDevice
    public let commandBuffer: MTLCommandBuffer
}

/// 渲染类：同步、必须每帧、只做 GPU 操作，禁止阻塞。
public protocol FrameProcessor: Sendable {
    var id: PluginID { get }
    func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture
}
```

```swift
/// 分析类：异步、可丢帧，产出元数据而非修改帧。preferredFPS 由各插件独立声明采样率。
public protocol FrameAnalyzer: Sendable {
    var id: PluginID { get }
    var preferredFPS: Int { get }
    func analyze(_ frame: Frame) async -> [Annotation]
}
```

### `CameraPipeline/Sources/CameraPipeline/PipelineController.swift`

```swift
// Metal 的协议类型（MTLTexture 等）还没有被 Apple 标注 Sendable，@preconcurrency 让编译器
// 把跨 actor 边界传递这些类型当作"未审计、由调用方负责"处理，而不是当成硬错误拦下来。
@preconcurrency import Metal

public actor PipelineController {

    private var processors: [any FrameProcessor] = []
    private var analyzers: [any FrameAnalyzer] = []
    private var inFlightAnalysisTask: Task<Void, Never>?

    // 两个 continuation 都是私有的，只在本 actor 内部（consume 及其派生的 Task）使用，
    // 保持普通 actor-isolated 存储即可，不需要 nonisolated。
    private let annotationContinuation: AsyncStream<[Annotation]>.Continuation
    private let renderedFrameContinuation: AsyncStream<MTLTexture>.Continuation

    public nonisolated let annotations: AsyncStream<[Annotation]>
    // renderedFrames 对外暴露给 CameraUI.ProcessedPreviewContainer（非 async 的
    // UIViewRepresentable.makeUIView 里消费），MTLTexture 不是 Sendable，用 nonisolated(unsafe)
    // 声明为可安全跨隔离域读取（原因同 CameraCore.CameraSession.previewLayer：init 赋值一次后不再变）。
    public nonisolated(unsafe) let renderedFrames: AsyncStream<MTLTexture>

    public init() {
        var annotationContinuation: AsyncStream<[Annotation]>.Continuation!
        annotations = AsyncStream { annotationContinuation = $0 }
        var renderedFrameContinuation: AsyncStream<MTLTexture>.Continuation!
        renderedFrames = AsyncStream { renderedFrameContinuation = $0 }

        self.annotationContinuation = annotationContinuation
        self.renderedFrameContinuation = renderedFrameContinuation
    }

    public func setProcessors(_ ps: [any FrameProcessor]) {
        processors = ps
    }

    public func setAnalyzers(_ newAnalyzers: [any FrameAnalyzer]) {
        analyzers = newAnalyzers
    }

    /// CameraCore.frames 的消费入口：渲染链同步跑完立刻产出 renderedFrames；
    /// 分析链按 latest-frame-wins 丢帧调度——新帧到达时若上一轮分析未完成，取消旧任务而不是排队。
    public func consume(_ frame: Frame, texture: MTLTexture, context: RenderContext) {
        var output = texture
        for processor in processors {
            output = processor.process(output, context: context)
        }
        renderedFrameContinuation.yield(output)

        guard !analyzers.isEmpty else { return }

        inFlightAnalysisTask?.cancel()
        let analyzers = self.analyzers
        inFlightAnalysisTask = Task {
            var collected: [Annotation] = []
            for analyzer in analyzers {
                if Task.isCancelled { return }
                collected.append(contentsOf: await analyzer.analyze(frame))
            }
            if !Task.isCancelled {
                self.annotationContinuation.yield(collected)
            }
        }
    }
}
```

### `CameraPipeline/Sources/CameraPipeline/Analyzer/HistogramAnalyzer.swift`

```swift
import Accelerate

/// 第一个内建 FrameAnalyzer 实现，不依赖 Vision framework，验证分析链的丢帧调度是否生效。
public struct HistogramAnalyzer: FrameAnalyzer {
    public let id = PluginID("histogram")
    public let preferredFPS: Int

    public init(preferredFPS: Int = 10) {
        self.preferredFPS = preferredFPS
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        // 用 vImage 直方图统计 pixelBuffer 的 R/G/B/Luminance 分布
        let data = HistogramData(redBuckets: [], greenBuckets: [], blueBuckets: [], luminanceBuckets: [])
        return [.histogram(data)]
    }
}
```

### `CameraUI/Sources/CameraUI/PreviewMode.swift`

```swift
public enum PreviewMode: Sendable, Equatable {
    case passthrough
    case processed
}
```

### `CameraUI/Sources/CameraUI/Preview/ProcessedPreviewContainer.swift`

```swift
// Metal 协议类型（MTLTexture）未标注 Sendable，见 CameraPipeline.PipelineController 顶部注释。
@preconcurrency import Metal
import MetalKit
import SwiftUI

import CameraPipeline

/// 消费 PipelineController.renderedFrames，与 Passthrough 二选一显示。
public struct ProcessedPreviewContainer: UIViewRepresentable {
    let renderedFrames: AsyncStream<MTLTexture>

    public init(renderedFrames: AsyncStream<MTLTexture>) {
        self.renderedFrames = renderedFrames
    }

    public func makeUIView(context: Context) -> MTKView {
        let device = MTLCreateSystemDefaultDevice()
        let view = MTKView(frame: .zero, device: device)
        context.coordinator.attach(view: view, stream: renderedFrames)
        return view
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {}

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        private var consumeTask: Task<Void, Never>?

        func attach(view: MTKView, stream: AsyncStream<MTLTexture>) {
            consumeTask?.cancel()
            consumeTask = Task { @MainActor [weak view] in
                for await texture in stream {
                    // Stage 2 先落骨架：真正把 texture 画进 view.currentDrawable 的渲染通路
                    // （MTLRenderPassDescriptor / MTLRenderCommandEncoder）留到接入真实渲染链时再补，
                    // 这里先确认流能驱动到 MainActor 消费端。
                    _ = view
                    _ = texture
                }
            }
        }

        deinit { consumeTask?.cancel() }
    }
}
```

（`Coordinator` 比早期草稿多了 `consumeTask` 生命周期管理——原草稿的 `attach` 只是空函数体的占位注释，实现时发现"用 Task 消费 AsyncStream"必须有地方存 Task 引用才能在 `deinit`/重新 `attach` 时取消，否则会有 Task 泄漏，所以补了这部分。）

**实现期修正（Xcode 编译时暴露）**：CLI 无法编译 `CameraUI`（见上方"验证方式"），这处 Swift 6 并发问题是用户在 Xcode 里实际编译时才发现并修复的：`Coordinator` 整体标了 `@MainActor`（而不是只在内部 `Task { @MainActor in ... }` 上标），`attach` 的 `stream` 参数加了 `consuming` 所有权修饰符（`func attach(view: MTKView, stream: consuming AsyncStream<MTLTexture>)`）。原因：`AsyncStream<MTLTexture>` 不是 Sendable，`Task { [weak view] in for await texture in stream ... }` 闭包想捕获它会被判定为跨隔离域传递；`consuming` 明确表达"这个 stream 参数被一次性转移进 Task，之后 `attach` 内不再使用它"，编译器就能放行，不需要再造一个 `@unchecked Sendable` 包装类型。这也印证了 Stage 1/2 里反复强调的一点：`CameraUI` 这类 UIKit 相关代码的并发问题，只有在 Xcode 里用 iOS destination 真正编译时才会暴露，CLI 上的 `swift build` 对它完全不适用。

### `CameraUI/Sources/CameraUI/Overlay/ScreenAnnotation.swift` / `OverlayCanvas.swift`

```swift
import CoreGraphics
import CameraPipeline

/// Annotation 转换到屏幕坐标后的展示模型（用 Shared.CoordinateConverter 转换）。
public enum ScreenAnnotation: Sendable {
    case quad(corners: [CGPoint])
    case histogram(CameraPipeline.HistogramData)
    case objects([CGRect])
    case horizon(angle: Double)
}
```

```swift
import SwiftUI

/// SwiftUI 端仅是 ForEach + Canvas 按类型画图，新增 Annotation 类型只需加一个绘制 case，
/// 不需要 UI 知道数据从哪来。本 stage 先接入 Grid / Level / Histogram 三种。
public struct OverlayCanvas: View {
    let annotations: [ScreenAnnotation]
    let showsGrid: Bool
    let showsLevel: Bool

    public init(annotations: [ScreenAnnotation], showsGrid: Bool, showsLevel: Bool) {
        self.annotations = annotations
        self.showsGrid = showsGrid
        self.showsLevel = showsLevel
    }

    public var body: some View {
        Canvas { context, size in
            if showsGrid { drawGrid(context: &context, size: size) }
            for annotation in annotations {
                draw(annotation, context: &context, size: size)
            }
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) { /* 三分线 */ }
    private func draw(_ annotation: ScreenAnnotation, context: inout GraphicsContext, size: CGSize) {
        switch annotation {
        case .histogram(let data): break // 画直方图曲线
        case .horizon(let angle): break  // 画水平仪
        case .quad(let corners): break   // Stage 3 才会真正产出
        case .objects: break
        }
    }
}
```

### `CameraCore/Sources/CameraCore/CapturePhoto+DualTrack.swift`

```swift
import AVFoundation
import Shared

/// CapturePhotoUseCase 双轨落盘的 Core 层支撑：DNG 原样保存（不 crop 不 filter），
/// 并行产出 HEIF；EXIF 写入拍摄参数/镜头/GPS。
extension CameraSession {
    func captureDualTrack(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult {
        // AVCapturePhotoOutput 配置 rawPhotoPixelFormatType + 同时请求 processed HEIF
        // 完成回调里分别写盘：rawFileURL（DNG 原样）与 processedFileURL（HEIF + EXIF）
        preconditionFailure("Fill in AVCapturePhotoCaptureDelegate bridging")
    }
}
```

### `CameraUI/Sources/CameraUI/State/CameraViewState.swift`（修改 Stage 1 占位版本）

```swift
import CameraCore
import CameraPipeline

/// 替换 Stage 1 的 CameraPreviewModePlaceholder 为正式 PreviewMode，
/// 新增 annotations（已转换为屏幕坐标，供 OverlayCanvas 直接消费）。
public struct CameraViewState: Sendable {
    public var capability: DeviceCapability
    public var manual: ManualSettingsPlaceholder   // Stage 4 替换为 CameraFeature.ManualSettings
    public var annotations: [ScreenAnnotation]
    public var previewMode: PreviewMode
    // activePreset: PresetID? 在 Stage 4 补充

    public init(capability: DeviceCapability, manual: ManualSettingsPlaceholder, annotations: [ScreenAnnotation] = [], previewMode: PreviewMode = .passthrough) {
        self.capability = capability
        self.manual = manual
        self.annotations = annotations
        self.previewMode = previewMode
    }
}
```

## Package.swift 变更

`Packages/Camera/CameraPipeline/Package.swift`：新建包，沿用 `CaseIterable` enum 模式，**无 SPM 依赖**（见上方"实现期修正"第 1 条——不依赖 `Shared`），`platforms: [.iOS(.v18), .macOS(.v11)]`（加 `.macOS(.v11)` 是为了让 `swift build`/`swift test` 能在本机 macOS host 上跑，`import Metal`/`Accelerate`/`simd` 本身在 macOS 上早就可用，不需要 macOS 11，但保持和 `Shared`/`CameraCore`/`CameraFeature` 一致的写法）。

`Packages/Camera/CameraUI/Package.swift`：追加对 `CameraPipeline` 的依赖（`.package(path: "../CameraPipeline")`），target 依赖数组新增 `.product(name: "CameraPipeline", package: "CameraPipeline")`。`platforms` 仍然只有 `[.iOS(.v18)]`（不加 `.macOS`，理由见 Stage 1 文档）。

`Packages/Camera/CameraCore/Package.swift`：无新增依赖，只是新增源文件（`CapturePhoto+DualTrack.swift`），并把 `CameraSession.capturePhoto(_:)` 改为委托给它。

## 执行顺序

1. 创建 `CameraPipeline` 包，先落 `Model/`（Frame、FrameMetadata、Annotation）与 `Protocol/`（FrameProcessor、FrameAnalyzer），跑 `swift build`
2. 实现 `PipelineController`，重点写 `PipelineControllerLatestWinsTests`：验证"新帧到达时取消旧分析任务而不是排队"
3. 实现 `HistogramAnalyzer`，接入 `PipelineController.setAnalyzers`，验证 Histogram 开启不影响渲染链帧率
4. 用 Stage 1 的 `FramePlaybackProvider` 驱动上述单测，全程不接真机
5. 扩展 `CameraUI`：`PreviewMode`、`ProcessedPreviewContainer`、`OverlayCanvas`，接入 Grid/Level Overlay
6. 在 `CameraCore` 补 `captureDualTrack`，实现 RAW(DNG) + HEIF 双轨落盘和 EXIF 写入
7. 用 Stage 1 的调试入口手动验收：开启/关闭 Histogram，观察预览帧率是否受影响；旋转设备验证 Overlay 对齐

## 验收清单

（原文档第 13 节 Stage 2 验收项，逐条保留）

- [ ] 空渲染链时预览稳定 30/60fps
- [ ] Histogram 开启不影响预览帧率（分析链独立采样）
- [ ] 旋转/镜像下 Overlay 与画面严格对齐
- [ ] RAW(DNG) + HEIF 双轨落盘，EXIF 完整

## 验证方式

```bash
cd Packages/Camera/CameraPipeline && swift build && swift test  # 4/4 tests passed
cd Packages/Camera/CameraCore && swift build && swift test      # 3/3 tests passed（含 dual-track 委托）
cd Packages/Camera/CameraFeature && swift build && swift test   # 3/3 tests passed（回归确认未受影响）
```

`Packages/Camera/CameraUI` 依然无法用 `swift build` 在本机验证——不只是 UIKit 类型缺失的问题：即使用 `-Xswiftc -sdk <iPhoneSimulator SDK> -Xswiftc -target arm64-apple-ios18.0-simulator` 显式指定 iOS 模拟器目标，SwiftPM 在真正编译前会先做一次"整个依赖图的 platform 兼容性"校验——`CameraUI` 没声明 `.macOS`，但它依赖的 `Shared`/`CameraCore`/`CameraPipeline` 都声明了 `.macOS(.v11)`，这个校验在选择目标三元组之前就会报错拦下来（`requires macos 10.13, but depends on...`），与实际要编译到哪个平台无关。这是 SwiftPM 工具链本身的限制，不是代码问题——`CameraUI` 只能通过 Xcode 里的 iOS 模拟器/真机 destination 编译验证。

`PipelineControllerLatestWinsTests` 用真实 `MTLCreateSystemDefaultDevice()` 创建 1×1 纹理跑测试（Apple Silicon Mac 上必有可用 GPU），不是 mock；latest-frame-wins 测试用 200ms 延迟的 `SlowAnalyzer` + 20ms 帧间隔验证：第一次 `consume` 触发的分析任务在第二次 `consume` 到达时应被取消（`cancelledIDs == [PluginID("slow")]`），只有第二次的分析任务跑完（`completedIDs == [PluginID("slow")]`）。

真机手动验收（需要 `CameraSession` 的真实 AVFoundation 配置先补上，见下方"已知限制"）：用 Instruments 测预览帧率（对照空渲染链 vs 开 Histogram）；旋转设备 90°/180°/270° 核对 Overlay 对齐；拍照后检查系统相册里 DNG 与 HEIF 是否成对出现且 EXIF 字段完整。

## 已知限制（部分已解决）

`CameraSession` 内部真实的 AVFoundation 配置（`configureOutputs()` 里的 `AVCapturePhotoOutput`/`AVCaptureVideoDataOutput`、真实 `capturePhoto` 的 `AVCapturePhotoCaptureDelegate` 桥接、真实 frame 产出）已经在 [`docs/plans/avfoundation_capture_layer_followup.md`](./avfoundation_capture_layer_followup.md) 里补齐，`captureDualTrack` 不再是占位实现。但这**没有**让本 stage 的验收项全部可用：
- `PipelineController` 本身（latest-wins 调度、Histogram 分析器）已经用单测充分验证，逻辑是可信的，这点不变；
- `FrameOutputDelegate` 产出的是 `CameraCore.Frame`（只有 pixelBuffer+timestamp），而 `PipelineController.consume(...)` 要的是 `CameraPipeline.Frame`（多 orientation/cameraMetadata）+ 一个已经零拷贝转换好的 `MTLTexture`——这两步转换（`CameraCore.Frame → CameraPipeline.Frame`，以及 `CVPixelBuffer → MTLTexture` 的 `CVMetalTextureCache` 桥接）**仍然没有实现**，谁在哪一层做这个转换还没有决定。也就是说：预览现在会显示真实画面（Passthrough 模式），但 "预览稳定 30/60fps""Histogram 不影响帧率""Overlay 与画面对齐" 这三条验收项依赖 Pipeline 真正收到帧，仍然跑不通；"RAW+HEIF 双轨落盘"这一条已经是真实实现，可以真机验收。

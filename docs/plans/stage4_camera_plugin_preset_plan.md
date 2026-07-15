# Stage 4：插件生态 + Preset（V5）

> 专业相机架构第四阶段（最后一阶段）：接入 CoreML 插件容器与滤镜插件，落地 CameraPreset（跨镜头 clamp + 持久化）、PluginRegistry 组合根注册，以及热降级策略。完成后，新增一个 ML 模型或滤镜只需"新类型 + 组合根一行注册"，L1/L2/L4 零改动。

来源文档：`docs/specs/iOS_Professional_Camera_Architecture_V2.md` 第 6（热降级规则）、7（CameraML/CameraFilters）、8（CameraPreset）、10（ThermalPolicyUseCase/PresetUseCase）、11（App 组合根）、13（Stage 4）节。

## 背景

Stage 1-3 依次交付了采集层、双链 Pipeline、Vision 检测与自动裁剪，架构的"分层合理""UI 低耦合"两条要求已经成立。本 stage 是"易扩展"这条要求的最终验证：新增 `MLModelPlugin`（如 YOLO/Pose/Food）与 `FrameProcessor`（如 LUT/美颜滤镜）都必须只需要一个新类型 + App 组合根一行注册，不允许触碰 `CameraPipeline`/`CameraVision`/`CameraUI`/`CameraFeature` 已有代码。同时把 Preset（跨镜头参数收敛）与热管理策略补齐，整套 V1+V4+V5 架构在本 stage 收口。

## 设计概要

- 分层依赖规则（本 stage 相关部分）：
  - `CameraML` / `CameraFilters` 依赖 `CameraPipeline`（仅协议）+ `Shared`，**禁止**依赖 `CameraCore` / `CameraUI`，与 `CameraVision` 同层（L3 插件实现层）
  - `App`（`MyEcommerce/`）是唯一 import 全部 Camera 包的地方——与仓库现有 `AppWebRouteFactory` / `AppRouteFactoryRegistrar` 同一模式：协议在低层包定义，实现分散在插件包，装配只发生在 App
- **CameraPreset 应用流程**（含 clamp）：`Preset → CapabilityValidator.clamp(preset, capability)`（例如 ISO 3200 在超广角镜头上收敛到合法值）→ `CameraCore.apply(controls)` → `PluginRegistry.resolve(ids)` → `Pipeline.setProcessors/Analyzers`。校验失败降级而非报错，同时上报 UI 提示。内置 Preset：Document（DocumentAnalyzer + 自动裁剪开）/ Portrait / Food / Night。
- **热降级策略**：`thermal serious` → 分析链降频；`thermal critical` → 停分析链 + 回落 passthrough。`ThermalPolicyUseCase` 订阅 Stage 1 `CameraSession` 预留的 thermal 事件流，调用 `PipelineController.setAnalyzers([])` 与切换 `PreviewMode`。
- **ProcessedPreview 自动切换**：Stage 2 已定义 `processors.isEmpty ? .passthrough : .processed` 规则，本 stage 由 `PresetUseCase` 在应用 Preset 时驱动这个切换，UI 仍然不感知。

## 新增文件

```
Packages/Camera/CameraML/
├── Package.swift
├── Sources/CameraML/
│   ├── MLModelPlugin.swift
│   └── Sample/
│       └── YOLOPlugin.swift              // 示例实现，验证协议可用
└── Tests/CameraMLTests/
    └── MLModelPluginPipelineTests.swift

Packages/Camera/CameraFilters/
├── Package.swift
├── Sources/CameraFilters/
│   ├── CIFilterProcessor.swift
│   ├── LUTProcessor.swift
│   ├── MetalShaderProcessor.swift
│   └── BeautyProcessor.swift
└── Tests/CameraFiltersTests/
    └── LUTProcessorTests.swift

Packages/Camera/CameraFeature/Sources/CameraFeature/
├── Model/
│   ├── CameraPreset.swift
│   ├── PluginID+WellKnown.swift
│   └── CapabilityValidator.swift
├── PluginRegistry.swift
└── UseCase/
    ├── ThermalPolicyUseCase.swift
    └── PresetUseCase.swift

MyEcommerce/Routing/
└── AppCameraComposition.swift             // App 组合根：唯一 import 全部 Camera 包的地方

Packages/Camera/CameraUI/Sources/CameraUI/State/
├── CameraViewState.swift                  // 修改：补 activePreset，manual 换成正式类型
└── CameraAction.swift                     // 修改：补 .applyPreset(PresetID)
```

### `CameraML/Sources/CameraML/MLModelPlugin.swift`

```swift
import CoreML
import CameraPipeline

public protocol MLModelPlugin: FrameAnalyzer {
    associatedtype Input
    associatedtype Output
    var model: MLModel { get }
    func preprocess(_ frame: Frame) -> Input
    func postprocess(_ output: Output) -> [Annotation]
}
```

### `CameraML/Sources/CameraML/Sample/YOLOPlugin.swift`

```swift
import CoreML
import CameraPipeline

/// 示例实现：验证"新增一个 CoreML 模型仅需新类型 + 注册一行"这条验收标准。
/// 模型加载惰性化 + 可卸载（内存压力时 Feature 层触发卸载）。
public final class YOLOPlugin: MLModelPlugin {
    public let id = PluginID("yolo")
    public let preferredFPS = 6
    public private(set) lazy var model: MLModel = try! MLModel(contentsOf: Self.modelURL)

    private static var modelURL: URL {
        Bundle.module.url(forResource: "YOLO", withExtension: "mlmodelc")!
    }

    public init() {}

    public func preprocess(_ frame: Frame) -> CVPixelBuffer { frame.pixelBuffer }

    public func postprocess(_ output: MLFeatureProvider) -> [Annotation] {
        // 解析 YOLO 输出 -> [DetectedObject] -> .objects(...)
        [.objects([])]
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let input = preprocess(frame)
        // 用 model 跑推理，postprocess(output)
        return [.objects([])]
    }

    public func unload() {
        // 内存压力时 Feature 层调用：置空 lazy var 持有的模型引用
    }
}
```

### `CameraFilters/Sources/CameraFilters/CIFilterProcessor.swift`

```swift
import CoreImage
import CameraPipeline

/// 全部实现 FrameProcessor，内部统一走 Metal；CIFilter 用共享 CIContext(mtlDevice:)。
public struct CIFilterProcessor: FrameProcessor {
    public let id: PluginID
    private let filter: CIFilter
    private let ciContext: CIContext

    public init(id: PluginID, filter: CIFilter, ciContext: CIContext) {
        self.id = id
        self.filter = filter
        self.ciContext = ciContext
    }

    public func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture {
        // texture -> CIImage -> filter -> render 回 MTLTexture，全程走 ciContext(mtlDevice:)，
        // 禁止 CIImage <-> UIImage 往返（内存铁律，Stage 2 已定义）。
        texture
    }
}
```

### `CameraFilters/Sources/CameraFilters/LUTProcessor.swift`

```swift
import CoreImage
import CameraPipeline

/// .cube 文件解析 + 3D 纹理采样。
public struct LUTProcessor: FrameProcessor {
    public let id: PluginID
    private let lutTexture: MTLTexture

    public init(id: PluginID, cubeFileURL: URL, device: MTLDevice) {
        self.id = id
        self.lutTexture = Self.loadCubeLUT(from: cubeFileURL, device: device)
    }

    public func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture {
        // MetalShaderProcessor 风格的 compute pipeline，对每个像素做 3D LUT 采样
        texture
    }

    private static func loadCubeLUT(from url: URL, device: MTLDevice) -> MTLTexture {
        preconditionFailure("Parse .cube file into a 3D MTLTexture")
    }
}
```

### `CameraFilters/Sources/CameraFilters/MetalShaderProcessor.swift` / `BeautyProcessor.swift`

```swift
// MetalShaderProcessor：通用 compute/render pipeline 包装器，接收自定义 .metal 函数名，
// 供 LUTProcessor / BeautyProcessor 复用同一套 MTLComputePipelineState 构建逻辑。
// BeautyProcessor：磨皮/美白，基于 MetalShaderProcessor 实现，FrameProcessor 协议一致。
```

### `CameraFeature/Sources/CameraFeature/Model/CameraPreset.swift`

```swift
import CameraCore
import CameraPipeline
import Shared

public struct ManualSettings: Codable, Sendable {
    public var iso: Float?
    public var shutterSeconds: Double?
    public var exposureBias: Float?
}

public enum CaptureFormat: String, Codable, Sendable {
    case raw, heif, rawPlusHeif
}

public struct CameraPreset: Codable, Sendable {
    public var name: String
    public var lens: LensType
    public var manual: ManualSettings?        // nil = 自动
    public var processorIDs: [String]         // 只存 ID，不存实例（PluginID 的 rawValue）
    public var analyzerIDs: [String]
    public var captureFormat: CaptureFormat

    public static let document = CameraPreset(
        name: "Document", lens: .wide, manual: nil,
        processorIDs: [], analyzerIDs: ["document"], captureFormat: .rawPlusHeif
    )
    public static let portrait = CameraPreset(
        name: "Portrait", lens: .wide, manual: nil,
        processorIDs: ["beauty"], analyzerIDs: ["face"], captureFormat: .heif
    )
    public static let food = CameraPreset(
        name: "Food", lens: .wide, manual: ManualSettings(iso: nil, shutterSeconds: nil, exposureBias: 0.3),
        processorIDs: ["lut.food"], analyzerIDs: [], captureFormat: .heif
    )
    public static let night = CameraPreset(
        name: "Night", lens: .wide, manual: ManualSettings(iso: 1600, shutterSeconds: nil, exposureBias: nil),
        processorIDs: [], analyzerIDs: [], captureFormat: .rawPlusHeif
    )
}
```

### `CameraFeature/Sources/CameraFeature/Model/CapabilityValidator.swift`

```swift
import CameraCore

public enum CapabilityValidator {
    /// ISO 3200 在超广角上收敛到合法值等场景。校验失败降级而非报错，Feature 层负责上报 UI 提示。
    public static func clamp(_ preset: CameraPreset, capability: DeviceCapability) -> CameraPreset {
        var clamped = preset
        if let iso = clamped.manual?.iso {
            clamped.manual?.iso = min(max(iso, capability.isoRange.lowerBound), capability.isoRange.upperBound)
        }
        if !capability.supportsRAW, clamped.captureFormat != .heif {
            clamped.captureFormat = .heif
        }
        return clamped
    }
}
```

### `CameraFeature/Sources/CameraFeature/PluginRegistry.swift`

```swift
import CameraPipeline

/// App 组合根往这里注册所有 FrameProcessor / FrameAnalyzer 实现，PresetUseCase 按 ID 解析。
/// 新增能力 = 新类型 + registry.register 一行，本文件本身不需要因为新插件而改动。
public final class PluginRegistry {
    private var processors: [String: any FrameProcessor] = [:]
    private var analyzers: [String: any FrameAnalyzer] = [:]

    public init() {}

    public func register(_ processor: any FrameProcessor, id: PluginID) {
        processors[id.rawValue] = processor
    }

    public func register(_ analyzer: any FrameAnalyzer, id: PluginID) {
        analyzers[id.rawValue] = analyzer
    }

    public func resolveProcessors(_ ids: [String]) -> [any FrameProcessor] {
        ids.compactMap { processors[$0] }
    }

    public func resolveAnalyzers(_ ids: [String]) -> [any FrameAnalyzer] {
        ids.compactMap { analyzers[$0] }
    }
}
```

### `CameraFeature/Sources/CameraFeature/UseCase/PresetUseCase.swift`

```swift
import CameraCore
import CameraPipeline

public struct PresetUseCase {
    private let cameraSource: any CameraSourceProtocol
    private let pipeline: PipelineController
    private let registry: PluginRegistry

    public init(cameraSource: any CameraSourceProtocol, pipeline: PipelineController, registry: PluginRegistry) {
        self.cameraSource = cameraSource
        self.pipeline = pipeline
        self.registry = registry
    }

    public func apply(_ preset: CameraPreset, capability: DeviceCapability) async throws {
        let clamped = CapabilityValidator.clamp(preset, capability: capability)
        if let manual = clamped.manual {
            if let iso = manual.iso { try await cameraSource.apply(.setISO(iso)) }
            if let bias = manual.exposureBias { try await cameraSource.apply(.setExposureBias(bias)) }
        }
        await pipeline.setProcessors(registry.resolveProcessors(clamped.processorIDs))
        await pipeline.setAnalyzers(registry.resolveAnalyzers(clamped.analyzerIDs))
        // ProcessedPreview 自动切换：processors.isEmpty ? .passthrough : .processed（Stage 2 规则）
    }
}
```

### `CameraFeature/Sources/CameraFeature/UseCase/ThermalPolicyUseCase.swift`

```swift
import CameraPipeline

public enum ThermalState: Sendable { case nominal, fair, serious, critical }

public struct ThermalPolicyUseCase {
    private let pipeline: PipelineController

    public init(pipeline: PipelineController) {
        self.pipeline = pipeline
    }

    public func handle(_ state: ThermalState) async {
        switch state {
        case .serious:
            // 分析链降频：不清空 analyzers，而是让 PipelineController 支持一个全局降采样系数（本 stage 补充到 PipelineController）
            break
        case .critical:
            await pipeline.setAnalyzers([])  // 停分析链
            // + 通知 UI 层强制回落 passthrough
        case .nominal, .fair:
            break
        }
    }
}
```

### `MyEcommerce/Routing/AppCameraComposition.swift`

```swift
import CameraCore
import CameraPipeline
import CameraVision
import CameraML
import CameraFilters
import CameraFeature

/// App 是唯一 import 全部 Camera 包的地方，与现有 AppWebRouteFactory / AppRouteFactoryRegistrar 同一模式。
enum AppCameraComposition {
    @MainActor static func makeCameraFeature() -> CameraFeatureContext {
        let registry = PluginRegistry()
        registry.register(LUTProcessor(id: PluginID("lut.food"), cubeFileURL: .foodLUT, device: MTLCreateSystemDefaultDevice()!), id: PluginID("lut.food"))
        registry.register(BeautyProcessor(), id: PluginID("beauty"))
        registry.register(DocumentAnalyzer(), id: PluginID("document"))
        registry.register(FaceAnalyzer(), id: PluginID("face"))
        registry.register(YOLOPlugin(), id: PluginID("yolo"))   // 新增能力只加这一行

        let camera = CameraSession()
        let pipeline = PipelineController()
        return CameraFeatureContext(
            presetUseCase: PresetUseCase(cameraSource: camera, pipeline: pipeline, registry: registry),
            thermalPolicyUseCase: ThermalPolicyUseCase(pipeline: pipeline),
            documentCaptureUseCase: DocumentCaptureUseCase(cameraSource: camera, pipeline: pipeline)
        )
    }
}

struct CameraFeatureContext {
    let presetUseCase: PresetUseCase
    let thermalPolicyUseCase: ThermalPolicyUseCase
    let documentCaptureUseCase: DocumentCaptureUseCase
}
```

### `CameraUI/Sources/CameraUI/State/CameraViewState.swift` / `CameraAction.swift`（收口 Stage 1/2 的占位类型）

```swift
import CameraCore
import CameraPipeline
import CameraFeature   // 正式 ManualSettings、PresetID 来自这里

public typealias PresetID = String  // 对应 CameraPreset.name，或后续换成专门的标识类型

/// 最终版本：manual 换成 CameraFeature.ManualSettings（不再是 Stage 1 的占位类型），
/// 新增 activePreset。annotations / previewMode 沿用 Stage 2。
public struct CameraViewState: Sendable {
    public var capability: DeviceCapability
    public var manual: ManualSettings
    public var annotations: [ScreenAnnotation]
    public var previewMode: PreviewMode
    public var activePreset: PresetID?
}
```

```swift
import CameraCore
import CoreGraphics
import CoreMedia
import Shared

/// 补上 Stage 1 里注释掉的 .applyPreset(PresetID)。
public enum CameraAction: Sendable {
    case setISO(Float), setShutter(CMTime), setEV(Float), setWB(WBGains)
    case focus(at: CGPoint), switchLens(LensType)
    case applyPreset(PresetID), capture
}
```

## Package.swift 变更

`Packages/Camera/CameraML/Package.swift`、`Packages/Camera/CameraFilters/Package.swift`：均新建，依赖 `Shared` + `CameraPipeline`（仅协议），不依赖 `CameraCore`/`CameraUI`，与 `CameraVision` 结构一致。

`Packages/Camera/CameraFeature/Package.swift`：追加对 `CameraML` **不**做包依赖（`PluginRegistry` 只存运行期实例，类型经 App 层注入，`CameraFeature` 编译期不知道 `CameraML`/`CameraFilters`/`CameraVision` 的存在——这是"L1/L2/L4 零改动"的关键：新插件包只需被 App 依赖）。

App 主 target（`MyEcommerce.xcodeproj`）：新增对 `Packages/Camera/*` 全部 8 个包的依赖（Xcode target 里添加 local Swift package 依赖，或在 `MyEcommerce/Package.swift`-等价的 Xcode 配置里声明，具体操作在实际执行 Stage 4 时于 Xcode 中完成，非纯文本可描述的 SPM 改动）。

## 执行顺序

1. 创建 `CameraML`、`CameraFilters` 两个包，落地协议与至少一个可运行的示例实现（`YOLOPlugin` 用占位 mlmodel 或 mock 推理即可，验证协议链路而非模型精度）
2. 在 `CameraFeature` 补 `CameraPreset` / `CapabilityValidator` / `PluginRegistry` / `PresetUseCase` / `ThermalPolicyUseCase`
3. 写 `PresetUseCase` 的 clamp 单测：构造一个超出 capability.isoRange 的 Preset，断言 clamp 后落在合法范围
4. 在 `PipelineController`（Stage 2 产物）补充"降频"支持，供 `ThermalPolicyUseCase.serious` 分支调用
5. 在 App 层新建 `AppCameraComposition.swift`，把此前三个 stage 的类型全部串起来注册
6. 手动验收：应用跨镜头 Preset 观察 clamp 生效；模拟 thermal critical（Instruments 或降级测试）观察是否回落 passthrough；实机测 LUT 滤镜开启后帧率

## 验收清单

（原文档第 13 节 Stage 4 验收项，逐条保留）

- [ ] 新增一个 CoreML 模型仅需新类型 + 注册一行，CameraUI 零改动
- [ ] Preset 跨镜头应用时非法参数被 clamp 且 UI 提示
- [ ] thermal critical 时自动回落 passthrough
- [ ] 实时 LUT 下预览 ≥30fps（A15 及以上）

## 验证方式

```bash
cd Packages/Camera/CameraML && swift build && swift test
cd Packages/Camera/CameraFilters && swift build && swift test
cd Packages/Camera/CameraFeature && swift build && swift test --filter CameraFeatureTests/CapabilityValidatorTests
```

真机手动验收：切换镜头后应用同一个 Preset，核对越界参数是否被收敛并弹出 UI 提示；用 Instruments 触发/模拟 thermal critical 状态，确认预览回落 passthrough 且分析链停止；开启 LUT 滤镜后用 Instruments 测帧率，确认 A15 及以上机型 ≥30fps。

## 实现期修正（B1-B3）

### B1：CameraFilters

- **`LUTProcessor` 没有按计划文档写"手写 Metal compute shader 采样 3D 纹理"**，改用系统内建的 `CIColorCube` 滤镜——理由跟 `CameraUI.ProcessedPreviewContainer` 选 `CIContext` 而不是手写 shader 一样：`CIColorCube` 本来就是做这件事的系统滤镜，效果完全等价，规避在 SPM 包里管理 `.metal` shader 编译这条额外出错面。`.cube` 文件解析是真实实现（Adobe `.cube` 文本格式，`LUT_3D_SIZE`/RGB 行/`TITLE`/`DOMAIN_MIN`/`DOMAIN_MAX`/注释都处理了），不是占位。
- **没有单独写 `MetalShaderProcessor.swift`**——`LUTProcessor` 改用 `CIColorCube` 后不再需要自定义 compute pipeline，`BeautyProcessor`（`CIGaussianBlur` + `CIColorMatrix` + `CISourceOverCompositing` 组合的简化磨皮）同样全程走 `CIContext`，两者共用一个 `renderProcessedTexture` 渲染尾段（`Support/CIImageRendering.swift`），都不需要手写 shader。
- **踩到一个真实的、非显而易见的坑**：`CIContext.render(_:to: MTLTexture, ...)` 的目标纹理只给 `[.shaderRead, .renderTarget]` usage 时会**静默不写任何数据**（不报错、不崩溃，纹理保持初始值）——必须加 `.shaderWrite`。第一版三个 processor 的像素级测试全部失败（输出全是 0），用一个独立探测脚本（构造纹理 + 试了 4 种 usage 组合）定位到这条，不是靠猜。这条坑已经写进 `CIImageRendering.swift` 的代码注释里，以后任何"手动创建 MTLTexture 当 CIContext 渲染目标"的代码都要留意。
- 三个 processor 全部有像素级验证的真实测试（不是"跑了不崩溃"这种形状测试）：`CIColorInvert` 验证颜色真的被反转；`LUTProcessor` 用一个真实解析的 2x2x2 identity/invert `.cube` 文件验证颜色变换正确；`BeautyProcessor` 验证硬边缘真的被软化。`CameraFilters` 11 tests。

### B2：CameraML

- **本仓库没有真实的 `.mlmodelc` 模型资产**（训练好的模型文件通常几十上百 MB，不适合提交进代码仓库）。因此没有照抄计划文档里 `try! MLModel(contentsOf:)` 那种一旦资源缺失就直接崩溃的写法，改成构造时 `throws`，`modelURL` 是调用方（真正拥有模型资产的 App）必传的参数，不是从 `Bundle.module` 找（`CameraML` 这个包没有声明任何 `resources:`，`Bundle.module` 根本不存在）。
- `analyze(_:)` 内部动态读模型自己声明的输入 feature 名字（`model.modelDescription.inputDescriptionsByName.keys.first`），不是硬编码猜一个名字（比如 `"image"`）——这样写对任意一个真实 CoreML 视觉模型都成立，不是针对某个特定模型调好的一次性脚本，但因为没有真实模型可用，这条路径本身没有被端到端跑通过。
- **诚实的限制**：`postprocess` 仍然是"有真实数据源但没写解析逻辑"的占位（YOLO 输出层的 anchor box 解码 + NMS 依赖具体模型的输出格式，没有真实模型就没法写具体解析），跟 `HistogramAnalyzer` 在 Stage 2 时的处境一样，不是伪造检测结果。测试只覆盖了"模型文件缺失/不合法时构造优雅抛错而不崩溃"这条唯一能诚实验证的路径。`CameraML` 2 tests。

### B3：Preset + PluginRegistry + 热降级

- `PresetUseCase.apply` 没有照抄计划文档里的 `throws` 签名——手动控制的 `cameraSource.apply` 调用改成 `try?` 静默吞掉错误，理由是"某个 control 在当前设备上暂时不支持"不应该连带阻止 processor/analyzer 的注册（跟计划文档自己"设计概要"里写的"校验失败降级而非报错"是同一个哲学，只是延伸到了手动控制这一步）。返回值从"什么都不返回"改成 `(clamped: CameraPreset, processorCount: Int)`，方便调用方知道 clamp 有没有真的改变了什么、以及要不要把预览切到 `.processed`。
- `ThermalPolicyUseCase.handle` 没有直接依赖 `CameraUI.PreviewMode`（计划文档的伪代码里隐含了这个依赖）——`CameraFeature` 不应该反向依赖 UI 层的具体类型，改成返回 `Bool`（"是否应该强制回落 passthrough"），由调用方自己映射到 UI 状态。
- **`PipelineController` 新增了计划文档提到但没给出实现的"分析链降频"支持**：`setAnalysisRateDivisor(_:)`，`.serious` 时每 N 帧只真正跑 1 次分析（不清空 analyzer 列表，跟 `.critical` 的"直接停"是两种不同强度的降级）。测试踩了一个真实的竞态坑：连续两次"真正触发分析"之间如果不等前一次跑完，会撞上 `consume()` 里 `inFlightAnalysisTask?.cancel()` 的取消逻辑，导致计数不稳定——修法是每次"hit"之后从 `annotations` 流里等一个值再发下一批，测试连续跑了 5 遍确认不 flaky。
- `CameraUI` 的 `ManualSettingsPlaceholder` 换成正式的 `CameraFeature.ManualSettings`，`CameraViewState` 补了 `activePreset: PresetID?`，`CameraAction` 补了 `.applyPreset(PresetID)`——`CameraUI/Package.swift` 新增对 `CameraFeature` 的依赖。这两个文件目前没有任何真实调用方（`CameraDebugView` 走的是自己的 `@Published` 属性，不是 State/Action 单向数据流），改动本身无法通过 CLI 验证（`CameraUI` 只声明了 `platforms: [.iOS(.v18)]`，从来没有 macOS 支持，这次新增的 `CameraFeature` 依赖也是同样的处境——`swift build` 在"Planning build"阶段就会因为 platform 校验失败，不是新引入的问题）。

**验证**：`CameraFeature` 从 10 涨到 27 tests（新增 `CapabilityValidator` 7 条、`PluginRegistry` 4 条、`PresetUseCase` 3 条、`ThermalPolicyUseCase` 3 条），`CameraPipeline` 从 10 涨到 13 tests（`setAnalysisRateDivisor` 3 条）。全量回归：

```
=== Shared ===        12 tests passed
=== CameraCore ===    5 tests passed
=== CameraPipeline === 13 tests passed
=== CameraVision ===  9 tests passed
=== CameraFeature === 27 tests passed
=== CameraFilters ===  11 tests passed
=== CameraML ===       2 tests passed
```

### B4：App 组合根

`MyEcommerce/Routing/AppCameraComposition.swift`——`enum AppCameraComposition { @MainActor static func makeCameraFeature() -> CameraFeatureContext }`，跟仓库现有 `AppRouteFactoryRegistrar` 同一模式（协议在低层包定义，插件实现分散在各插件包，装配只发生在 App 层）。

- **真实注册的插件**：CameraVision 全部 7 个 Vision-based analyzer（document/card/face/rectangle/barcode/ocr/horizon，都不依赖外部资产，Vision framework 内建）+ `HistogramAnalyzer` + `BeautyProcessor`（CameraFilters，纯 CIFilter 组合，不依赖外部资产）——这些无条件注册。
- **诚实处理缺资产的两个插件**：`YOLOPlugin`（需要真实 `.mlmodelc`）和 `LUTProcessor`（需要真实 `.cube` 文件）都是"尝试从 `Bundle.main` 加载，找不到就打日志跳过注册"，不让整个组合根因为一个可选插件缺资产而失败。注释里写清楚了真机验收前需要手动把这两个资产文件加进 Xcode target 的 Bundle Resources——这是本轮诚实的限制：`.mlmodelc` 是真实训练出来的模型（不适合、也没法凭空生成提交进仓库），`.cube` 是纯文本格式体积很小但仓库里也没有现成的可用文件。
- **`ThermalObserver`（新增，App 层）**：订阅真实的 `ProcessInfo.thermalStateDidChangeNotification`，收到通知就读 `ProcessInfo.processInfo.thermalState`、转成 `CameraFeature.ThermalState`（新增的 `ThermalState.init(systemThermalState:)` 映射，CLI 可测，见下）、驱动 `ThermalPolicyUseCase.handle`——这是 Stage 4 验收清单"thermal critical 时自动回落 passthrough"里"自动"二字的字面落地：不需要任何人手动触发，设备真的发热了就会自己降级。暴露一个 `shouldForcePassthrough: AsyncStream<Bool>` 给 UI 层订阅，阶段 C 的正式相机页面会用它切换 `CameraViewState.previewMode`。
- **目前没有被 `MyEcommerceApp.init()` 调用**——跟 B3 里 `CameraViewState`/`CameraAction` 一样的处境，接入 App 启动流程和真实相机页面是阶段 C 的工作，本轮只把组合根本身搭好。

**验证**：`ThermalState.init(systemThermalState:)` 是本轮唯一落在 CLI 可测包（`CameraFeature`）里的新增代码，4 个系统状态到自定义状态的映射全部验证。`AppCameraComposition.swift`/`ThermalObserver` 是 App target 代码，无法 CLI 验证（App target 本身就不是 SwiftPM 包），只能人工走查 + 等真机/Xcode 验收。

```
=== Shared ===        12 tests passed
=== CameraCore ===    5 tests passed
=== CameraPipeline === 13 tests passed
=== CameraVision ===  9 tests passed
=== CameraFeature === 28 tests passed（新增 ThermalState 系统映射 1 条）
=== CameraFilters ===  11 tests passed
=== CameraML ===       2 tests passed
```

**仍未完成 / 仍未验证**：
1. `MyEcommerce.xcodeproj` 需要新增对 `CameraFilters`/`CameraML` 两个包的依赖（App target 目前只显式链接了 `CameraCore`/`CameraFeature`/`CameraUI`，`CameraPipeline`/`Shared` 靠传递解析）——这两个新包是否也能走同样的传递解析路径没有实测过，是这轮最大的未知项。
2. `YOLO.mlmodelc`/`Food.cube` 两个资产文件都没有添加到 Xcode target，`YOLOPlugin`/`LUTProcessor` 的注册目前会在真机上被跳过（打印警告，不崩溃）。
3. `AppCameraComposition.makeCameraFeature()` 和 `ThermalObserver` 都还没有被 `MyEcommerceApp.init()` 调用过，没有任何真实运行时验证（包括 `ThermalObserver` 的 `deinit` 里访问 `@MainActor`-isolated 属性这种写法在 Swift 6 下是否真的按预期编译——只做了人工代码走查）。
4. `CameraViewState`/`CameraAction` 仍然没有真实调用方，等阶段 C。

阶段 B（Stage 4）到这里全部完成——插件生态（CameraFilters + CameraML）、Preset + clamp、PluginRegistry、热降级（含分析链降频 + 自动系统热事件观察）、App 组合根都已经是真实实现，CLI 可测部分全部覆盖，App/UI 层部分等真机验收。

## Xcode 编译报错修复：三个 UseCase 补 `Sendable` conformance

用户在 Xcode 里编译 `AppCameraComposition.swift` 时报错（第 136 行）：

```
Sending main actor-isolated 'self.thermalPolicyUseCase' to nonisolated instance method 'handle'
risks causing data races between nonisolated and main actor-isolated uses
```

**根因**：`ThermalPolicyUseCase`/`PresetUseCase`/`DocumentCaptureUseCase` 都是普通 `public struct`，虽然存储属性全是 Sendable 安全的（`PipelineController` 是 actor、`any CameraSourceProtocol` 因为协议本身 `: Actor` 所以存在型也是 Sendable、`PluginRegistry` 已经是 `@unchecked Sendable`），但没有显式声明 `: Sendable`——Swift 对 public 类型的隐式 Sendable 推导不保证跨模块可靠传播。`ThermalObserver`（`@MainActor` class）把 `thermalPolicyUseCase` 存成 MainActor-isolated 属性，在 `Task { @MainActor in ... }` 内部 `await self.thermalPolicyUseCase.handle(state)`——由于 `handle` 所在的类型在编译器看来"不确定是不是 Sendable"，跨 actor 边界传递就被 Swift 6 严格并发检查拦下来。

**修法**：给三个 UseCase 都显式加上 `: Sendable`（`ThermalPolicyUseCase.swift`、`PresetUseCase.swift`、`DocumentCaptureUseCase.swift`）——不只修报错的那一个，因为另外两个是完全一样的结构（存储属性都是 actor + 协议存在型的组合），阶段 C 一旦用同样的方式调用就会撞上同一个错误，一次性修掉比逐个报错逐个修更合理。

CLI 回归：`CameraFeature` 28/28、全量 80/80，无回退（这个改动纯粹是加 conformance 声明，不改变任何运行时行为）。

顺带记录：用户/Xcode 的 fix-it 同时调整了 `ThermalObserver.observer` 为 `nonisolated(unsafe)`、`deinit` 标了 `nonisolated`、`YOLOPlugin.analyze` 里 `model.prediction(from:)` 调用加了 `await`（这行在当前 SDK 上会有一条"no async operations occur"的无害警告，CoreML 该 API 在这个编译目标上不是真正 async，但 `await` 语法本身允许作用在非 async 表达式上，不算错误）。这些改动都已保留，不是本轮需要处理的问题。

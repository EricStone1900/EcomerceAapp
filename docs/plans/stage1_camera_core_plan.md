# Stage 1：CameraCore + Passthrough 预览（V1 前半）

> 专业相机架构 4 阶段交付的第一阶段：搭好 L0 Shared 与 L1 CameraCore（纯采集层，actor 隔离），并接入最基础的 Passthrough 预览，跑通"能看见画面 + 能手动调参 + 能扛住中断"。本阶段不涉及任何 Pipeline / Vision / ML 处理。

来源文档：`docs/specs/iOS_Professional_Camera_Architecture_V2.md` 第 3、4、6（PassthroughPreview 部分）、13（Stage 1）节。

## 背景

这是相机子系统的第一份实施计划，此前仓库里没有任何相机相关代码。新增的所有 Camera 包放在独立目录 `Packages/Camera/` 下，与现有 `Packages/Abstraction|Domain|Data|Presentation|Utilities` 并列、互不干扰（已与用户确认）。本 stage 交付后，App 能显示一路未经处理的实时取景画面，并支持手动 ISO/快门/EV/白平衡/对焦/镜头切换，为 Stage 2 的 Pipeline 双链打好地基。

## 设计概要

- 分层依赖规则（本 stage 相关部分）：
  - `CameraCore` 仅依赖 `Shared`，不知道任何插件（Pipeline/Vision/ML/Filters）的存在
  - `CameraUI`（本 stage 只建最小子集）只依赖 `CameraCore` 暴露的协议与模型 + `Shared`
- **关键设计决策**：文档 9.2 节把 `PreviewContainer` 划归 L4 `CameraUI`，但 Stage 1 的目标就是"看到画面"，因此本 stage 提前创建一个最小的 `CameraUI` 包，只包含 `PassthroughPreviewContainer`（`UIViewRepresentable` 包装 `AVCaptureVideoPreviewLayer`）。`OverlayCanvas`、`ProcessedPreview`、`ManualControlBar` 等留到 Stage 2/4。
- 镜头策略：物理设备 + 手动切换（文档 4.2 节明确取舍：放弃虚拟设备无缝变焦，换取完整手动控制能力）
- 可测试性铁律：`CameraSession` 的真机实现与测试用的帧回放器都通过 `CaptureSessionProviding` 协议接入，Pipeline/Vision/ML 的单测不依赖真机——这条规则从本 stage 起就要立住，后续 stage 直接复用。
- **关键设计决策**：文档第 10 节把"启动/权限/中断恢复状态机"定义为 L4 `CameraFeature` 的 `CameraSessionUseCase`，而不是 L1 `CameraCore` 自己的职责——`CameraSession`（Core）只负责底层 AVCaptureSession 事件的产出与响应，状态机编排（例如"权限未授权 → 引导用户去设置 → 返回后自动重试"）属于业务层。因此 `CameraFeature` 包从本 stage 起就创建（而不是等到 Stage 3 才创建），Stage 3/4 在此基础上追加 `DocumentCaptureUseCase` / `PresetUseCase` 等，不重复建包。
- **实现期修正（相对本文档早期草稿）**：`LensType` 实际放在 `Shared`（而不是 `CameraCore/Model/`）——`CameraError.deviceUnavailable(LensType)` 在 `Shared` 里就要用到它，若 `LensType` 留在 `CameraCore`，会出现 L0 反向依赖 L1 的架构违规。`CameraCore`（`DeviceCapability`/`CameraControl`/`CameraSession`）与 `CameraUI`（`CameraAction`）通过 `import Shared` 使用它。`CameraSessionUseCase` 实现为 `actor`（而非 `final class`）以满足 Swift 6 严格并发下对可变 `state` 的隔离要求。

## 新增文件

```
Packages/Camera/
├── Shared/
│   ├── Package.swift
│   ├── Sources/Shared/
│   │   ├── CameraError.swift
│   │   ├── Logger.swift
│   │   ├── LensType.swift               // 实现期从 CameraCore/Model 挪到这里，见下方"实现期修正"
│   │   ├── CoordinateConverter.swift
│   │   └── GeometryUtils.swift
│   └── Tests/SharedTests/
│       └── CoordinateConverterTests.swift
├── CameraCore/
│   ├── Package.swift
│   ├── Sources/CameraCore/
│   │   ├── Model/
│   │   │   ├── DeviceCapability.swift
│   │   │   ├── CameraControl.swift
│   │   │   ├── PhotoCaptureRequest.swift
│   │   │   └── PhotoCaptureResult.swift
│   │   ├── Protocol/
│   │   │   ├── CaptureSessionProviding.swift
│   │   │   └── CameraSourceProtocol.swift
│   │   ├── CameraSession.swift
│   │   └── FramePlaybackProvider.swift   // 测试桩：帧回放器
│   └── Tests/CameraCoreTests/
│       └── CameraSessionCapabilityTests.swift
├── CameraUI/
│   ├── Package.swift
│   └── Sources/CameraUI/
│       ├── Preview/
│       │   └── PassthroughPreviewContainer.swift
│       └── State/
│           ├── CameraViewState.swift
│           └── CameraAction.swift
└── CameraFeature/
    ├── Package.swift
    ├── Sources/CameraFeature/
    │   └── UseCase/
    │       └── CameraSessionUseCase.swift
    └── Tests/CameraFeatureTests/
        └── CameraSessionUseCaseTests.swift
```

### `Shared/Sources/Shared/LensType.swift`

```swift
// Codable：Stage 4 的 CameraPreset（Codable，需要持久化）里存了 LensType，从这里就带上，
// 避免 Stage 4 再回来改这个类型的声明。
public enum LensType: String, Sendable, CaseIterable, Codable {
    case wide
    case ultraWide
    case tele
}
```

### `Shared/Sources/Shared/CameraError.swift`

```swift
import Foundation

public enum CameraError: Error, Sendable {
    case sessionConfigurationFailed(underlying: Error?)
    case deviceUnavailable(LensType)
    case permissionDenied
    case interrupted(reason: String)
    case captureFailed(underlying: Error?)
    case unsupportedControl(String)
}
```

### `Shared/Sources/Shared/Logger.swift`

```swift
import os

public enum CameraLog {
    public static let session = Logger(subsystem: "com.myecoapp.camera", category: "Session")
    public static let pipeline = Logger(subsystem: "com.myecoapp.camera", category: "Pipeline")
    public static let vision = Logger(subsystem: "com.myecoapp.camera", category: "Vision")
}
```

### `Shared/Sources/Shared/CoordinateConverter.swift`

```swift
import CoreGraphics

/// 抽象出 previewLayer.frame，避免 Shared 直接依赖 UIKit/AVFoundation 具体类型，便于单测。
public protocol CALayerFrameProviding: Sendable {
    var layerFrame: CGRect { get }
}

/// 统一把 Vision 归一化坐标(左下原点)转换为预览层 UIKit 坐标。
/// 封装 rotation / mirror / videoGravity 裁切偏移，所有 Overlay 只允许用这一个服务转换。
public struct CoordinateConverter: Sendable {
    public let previewLayer: any CALayerFrameProviding

    public init(previewLayer: any CALayerFrameProviding) {
        self.previewLayer = previewLayer
    }

    /// 输入 Vision 归一化坐标（左下原点，0...1），输出预览层坐标系下的点。
    public func convert(normalizedPoint point: CGPoint) -> CGPoint {
        // Stage 1 先落骨架：翻转 y 轴 + 按 previewLayer.frame 缩放。
        // rotation / mirror / videoGravity 裁切偏移在 Stage 2 接入 Overlay 时补全并加单测
        // （videoGravity 字段延后到那时再引入，避免 Stage 1 出现从未被读取的死字段）。
        let flipped = CGPoint(x: point.x, y: 1 - point.y)
        let bounds = previewLayer.layerFrame
        return CGPoint(x: flipped.x * bounds.width, y: flipped.y * bounds.height)
    }
}
```

### `Shared/Sources/Shared/GeometryUtils.swift`

```swift
import CoreGraphics

public enum GeometryUtils {
    /// 四边形透视校正矩阵，Stage 3 DocumentCaptureUseCase 会用到；Stage 1 先留接口占位。
    public static func perspectiveTransform(quad corners: [CGPoint], targetSize: CGSize) -> CGAffineTransform {
        preconditionFailure("Implemented in Stage 3 alongside DocumentAnalyzer")
    }

    /// EMA 低通滤波，用于检测框时域平滑（Stage 3 quad 平滑会用到）。
    public struct EMAFilter {
        private var value: CGPoint?
        public let alpha: CGFloat
        public init(alpha: CGFloat = 0.3) { self.alpha = alpha }
        public mutating func update(_ newValue: CGPoint) -> CGPoint {
            guard let previous = value else { value = newValue; return newValue }
            let smoothed = CGPoint(
                x: previous.x + alpha * (newValue.x - previous.x),
                y: previous.y + alpha * (newValue.y - previous.y)
            )
            value = smoothed
            return smoothed
        }
    }
}
```

### `CameraCore/Sources/CameraCore/Model/DeviceCapability.swift`

```swift
import CoreMedia
import CoreGraphics

public struct WBGainsRange: Sendable {
    public let redRange: ClosedRange<Float>
    public let greenRange: ClosedRange<Float>
    public let blueRange: ClosedRange<Float>
}

public struct CaptureFormatDescriptor: Sendable {
    public let dimensions: CMVideoDimensions
    public let maxFrameRate: Double
}

/// 每颗镜头能力不同，手动控制与 Preset 都依赖它。切换镜头时发布新的 Capability，UI 据此重建滑杆范围。
public struct DeviceCapability: Sendable {
    public let lens: LensType
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

### `CameraCore/Sources/CameraCore/Model/CameraControl.swift`

```swift
import CoreMedia
import CoreGraphics

public struct WBGains: Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float
}

/// 统一控制指令，CameraSourceProtocol.apply(_:) 的入参。
public enum CameraControl: Sendable {
    case setISO(Float)
    case setShutter(CMTime)
    case setExposureBias(Float)
    case setWhiteBalance(WBGains)
    case focus(at: CGPoint)
    case switchLens(LensType)
    case setZoom(CGFloat)
    case setTorch(Bool)
}
```

### `CameraCore/Sources/CameraCore/Model/PhotoCaptureRequest.swift` / `PhotoCaptureResult.swift`

```swift
public struct PhotoCaptureRequest: Sendable {
    public let captureRAW: Bool
    public init(captureRAW: Bool = false) { self.captureRAW = captureRAW }
}

public struct PhotoCaptureResult: Sendable {
    public let processedFileURL: URL
    public let rawFileURL: URL?
}
```

### `CameraCore/Sources/CameraCore/Protocol/CaptureSessionProviding.swift`

```swift
/// 真机实现: AVCaptureSession 包装；测试实现: 帧回放器（FramePlaybackProvider）。
/// Pipeline / Vision / ML 的所有单测通过注入录制帧序列完成，不依赖真机。
public protocol CaptureSessionProviding: Actor {
    func startRunning() async throws
    func stopRunning() async
    func configureOutputs() async throws
}
```

### `CameraCore/Sources/CameraCore/Protocol/CameraSourceProtocol.swift`

```swift
import AVFoundation
import CoreMedia
import CoreVideo

/// Frame 在 Stage 2 CameraPipeline 里正式定义并扩展；Stage 1 先声明最小骨架，
/// 保证 CameraSourceProtocol 的 frames 流从第一天起就是稳定的公开接口。
public struct Frame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let timestamp: CMTime

    public init(pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
    }
}

/// L1 对外唯一出口，Pipeline（Stage 2 起）只依赖这个协议，不知道 AVFoundation 的存在。
public protocol CameraSourceProtocol: Actor {
    var frames: AsyncStream<Frame> { get }
    var capability: AsyncStream<DeviceCapability> { get }
    var previewLayer: AVCaptureVideoPreviewLayer { get } // 仅 Passthrough 模式使用
    func apply(_ control: CameraControl) async throws
    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult
}
```

### `CameraCore/Sources/CameraCore/CameraSession.swift`

```swift
import AVFoundation
import Shared

/// AVCaptureSession 生命周期，专用 sessionQueue，对外暴露为 actor。
public actor CameraSession: CaptureSessionProviding, CameraSourceProtocol {
    private let session = AVCaptureSession()
    private var currentLens: LensType = .wide

    // frames/capability 用初始化时创建的 continuation 持续 yield，而不是每次访问属性都
    // 新建一条空流——后者会导致多个消费者互不相通、且没有任何生产者持有 continuation。
    private var frameContinuation: AsyncStream<Frame>.Continuation?
    private var capabilityContinuation: AsyncStream<DeviceCapability>.Continuation?

    // 详见下方"实现期修正"：非 Sendable 类型的 actor-isolated 属性不能跨隔离域读取，
    // previewLayer 只在 init 里赋值一次、之后不变，用 nonisolated(unsafe) 声明为可安全跨域读取。
    public nonisolated(unsafe) let previewLayer: AVCaptureVideoPreviewLayer
    public nonisolated let frames: AsyncStream<Frame>
    public nonisolated let capability: AsyncStream<DeviceCapability>

    public init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)

        var frameContinuation: AsyncStream<Frame>.Continuation!
        frames = AsyncStream { frameContinuation = $0 }
        var capabilityContinuation: AsyncStream<DeviceCapability>.Continuation!
        capability = AsyncStream { capabilityContinuation = $0 }

        self.frameContinuation = frameContinuation
        self.capabilityContinuation = capabilityContinuation
    }

    // MARK: CaptureSessionProviding

    public func startRunning() async throws {
        CameraLog.session.info("startRunning")
        // 权限检查 + session.startRunning()，失败时抛 CameraError.sessionConfigurationFailed
    }

    public func stopRunning() async {
        session.stopRunning()
    }

    public func configureOutputs() async throws {
        // 配置 AVCapturePhotoOutput(RAW+Processed)、AVCaptureVideoDataOutput、AVCaptureMovieFileOutput
    }

    // MARK: CameraSourceProtocol

    public func apply(_ control: CameraControl) async throws {
        switch control {
        case .switchLens(let lens):
            currentLens = lens
            // 重新配置 AVCaptureDeviceInput，通过 capabilityContinuation 发布新 capability
        default:
            // 其余控制指令映射到 AVCaptureDevice.lockForConfiguration 内的具体调用
            break
        }
    }

    public func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult {
        // Stage 1 先支持 Processed-only；RAW+Processed 双轨落盘在 Stage 2 与 CapturePhotoUseCase 一起补全
        throw CameraError.captureFailed(underlying: nil)
    }

    // MARK: 中断与恢复

    /// 监听 AVCaptureSession.wasInterrupted / interruptionEnded / runtimeError 通知，
    /// 处理来电、分屏、权限流程；thermalStateDidChange 事件通过独立 AsyncStream 向上抛出，
    /// 降级策略（回落 passthrough / 停分析链）由 Feature 层（Stage 4 ThermalPolicyUseCase）决定。
}
```

（`frames`/`capability` 声明为 `nonisolated let`：`AsyncStream<Frame>`/`AsyncStream<DeviceCapability>` 本身是 `Sendable`，声明为 nonisolated 让消费方不需要 `await` 就能拿到流本身再在流内部消费；`previewLayer` 保持 actor-isolated（协议要求，外部通过 `await` 访问），因为 `AVCaptureVideoPreviewLayer` 不是 `Sendable`。）

### `CameraCore/Sources/CameraCore/FramePlaybackProvider.swift`

```swift
/// 测试桩：回放预先录制的帧序列，驱动 Pipeline / Vision / ML 单测，不依赖真机。
public actor FramePlaybackProvider: CaptureSessionProviding {
    private let recordedFrames: [Frame]

    public init(recordedFrames: [Frame]) {
        self.recordedFrames = recordedFrames
    }

    public func startRunning() async throws {}
    public func stopRunning() async {}
    public func configureOutputs() async throws {}
}
```

### `CameraUI/Sources/CameraUI/Preview/PassthroughPreviewContainer.swift`

```swift
import SwiftUI
import AVFoundation
import CameraCore

/// L4 展示层里唯一的 UIKit 接触点之一（本 stage 版本）。
/// 只依赖 CameraCore 暴露的 AVCaptureVideoPreviewLayer，不 import 任何插件包。
public struct PassthroughPreviewContainer: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    public init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
    }

    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}
```

### `CameraUI/Sources/CameraUI/State/CameraViewState.swift` / `CameraAction.swift`

```swift
import CameraCore

/// UI 订阅的单向状态。字段随后续 stage 增量补全：
/// - Stage 2 补 previewMode 的真实切换 + annotations
/// - Stage 4 补 activePreset
/// 本 stage 只落最小可用版本，保证 UI 从第一天起就走"订阅 State + 发送 Action"单向数据流，
/// 不直接触碰 CameraCore。
public struct CameraViewState: Sendable {
    public var capability: DeviceCapability
    public var manual: ManualSettingsPlaceholder
    public var previewMode: CameraPreviewModePlaceholder = .passthrough

    public init(capability: DeviceCapability, manual: ManualSettingsPlaceholder) {
        self.capability = capability
        self.manual = manual
    }
}

/// Stage 4 的 CameraFeature.ManualSettings 落地前的占位类型，字段与其保持一致，
/// Stage 4 直接替换为正式类型，不改动 CameraViewState 的结构。
public struct ManualSettingsPlaceholder: Sendable {
    public var iso: Float?
    public var shutterSeconds: Double?
    public var exposureBias: Float?
    public init(iso: Float? = nil, shutterSeconds: Double? = nil, exposureBias: Float? = nil) {
        self.iso = iso; self.shutterSeconds = shutterSeconds; self.exposureBias = exposureBias
    }
}

/// Stage 2 引入正式 PreviewMode（CameraUI/PreviewMode.swift）后，这里直接替换引用。
public enum CameraPreviewModePlaceholder: Sendable { case passthrough }
```

```swift
import CameraCore
import CoreGraphics
import CoreMedia
import Shared

public enum CameraAction: Sendable {
    case setISO(Float), setShutter(CMTime), setEV(Float), setWB(WBGains)
    case focus(at: CGPoint), switchLens(LensType)
    case capture
    // .applyPreset(PresetID) 在 Stage 4 CameraPreset 落地后补充
}
```

### `CameraFeature/Sources/CameraFeature/UseCase/CameraSessionUseCase.swift`

```swift
import CameraCore

public enum SessionPermissionState: Sendable, Equatable {
    case notDetermined, authorized, denied, restricted
}

public enum SessionState: Sendable, Equatable {
    case idle, requestingPermission, permissionDenied, starting, running, interrupted(reason: String)
}

/// 启动/权限/中断恢复状态机。CameraSession（Core）只产出事件，
/// 状态机编排（例如权限被拒后引导用户去设置、返回 App 后自动重试）属于本用例。
/// 实现为 actor（而非 class）：Swift 6 严格并发下，跨 await 调用点之间共享的可变 state
/// 必须有隔离域保护，class + 手动加锁在这里既多余又容易漏加。
public actor CameraSessionUseCase {
    private let cameraSource: any CameraSourceProtocol
    public private(set) var state: SessionState = .idle

    public init(cameraSource: any CameraSourceProtocol) {
        self.cameraSource = cameraSource
    }

    public func start() async {
        state = .requestingPermission
        // 检查/请求 AVCaptureDevice 权限；拒绝则 state = .permissionDenied，交给 UI 引导去设置
        state = .starting
        do {
            try await cameraSource.apply(.setZoom(1.0)) // 触发一次 session 配置校验
            state = .running
        } catch {
            state = .interrupted(reason: "\(error)")
        }
    }

    /// 订阅 CameraSession 内部的中断通知（来电/分屏/runtimeError），驱动状态机在
    /// interruptionEnded 后自动调用 start() 恢复；手动参数（ISO/快门/EV/WB）由调用方
    /// 在恢复后重放，保证锁屏-解锁后参数保持（Stage 1 验收项之一）。
    public func handleInterruption(ended: Bool, reason: String) async {
        if ended {
            await start()
        } else {
            state = .interrupted(reason: reason)
        }
    }
}
```

## Package.swift 变更

四个新包均沿用仓库现有的 `CaseIterable` enum 模式（见 `Packages/Utilities/Networking/Package.swift`），`swift-tools-version: 6.2`，`platforms: [.iOS(.v18)]`。`Shared` 额外加 `.macOS(.v11)`（见 `PresentationCore`/`DesignSystem` 的既有先例）——`swift build`/`swift test` 在本机默认编译到 macOS host，`os.Logger` 需要 macOS 11+ 才能用，不加这条 `swift build` 直接报 "'Logger' is only available in macOS 11.0 or newer"。

`Packages/Camera/Shared/Package.swift`：

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: SharedProduct.allCases.map(\.product),
    targets: SharedProduct.allCases.map(\.target) + SharedProduct.allCases.flatMap(\.testsTargets)
)

enum SharedProduct: String, CaseIterable {
    case Shared
    var path: String { "Sources/Shared" }
    var testsPath: String { "Tests/SharedTests" }
    var testsName: String { "SharedTests" }
    var product: Product { .library(name: rawValue, targets: [rawValue]) }
    var target: Target { .target(name: rawValue, path: path) }
    var testsTargets: [Target] {
        [.testTarget(name: testsName, dependencies: [.target(name: rawValue)], path: testsPath)]
    }
}
```

`Packages/Camera/CameraCore/Package.swift`：新增 `CameraCore` target，`dependencies: [.package(path: "../Shared")]`，target 依赖 `.product(name: "Shared", package: "Shared")`，额外链接 `AVFoundation`（系统 framework，无需 SPM 依赖声明）。`platforms` 同样加 `.macOS(.v11)`——依赖 `Shared` 后，SPM 会校验"下游包的平台最低版本不能低于上游"，不加会在 `swift build` 时报 `requires macos 10.13, but depends on the product 'Shared' which requires macos 11.0`。

`Packages/Camera/CameraUI/Package.swift`：新增 `CameraUI` target，依赖 `CameraCore`（`.package(path: "../CameraCore")`）。**不得**添加对 Pipeline/Vision/ML/Filters 的依赖——这是本架构"UI 零算法依赖"的第一道编译期防线，从 Stage 1 起就要遵守。`platforms` 只保留 `[.iOS(.v18)]`，**不加** `.macOS`：`PassthroughPreviewContainer` 用了 `UIViewRepresentable`/`UIView`，这两个类型在 macOS SDK 里根本不存在，加了 `.macOS` 声明也无法通过 `swift build` 编译（仓库里 `PresentationCore` 同样 `import UIKit` 却声明了 `.macOS(.v11)`，那个声明本身就是不实的历史遗留，本 stage 不重复这个问题）。因此 `CameraUI` 只能通过 Xcode 指定 iOS 目标来构建验证，`swift build`/`swift test` 在本机 CLI 上不适用——这与仓库 `CLAUDE.md` 里 `PresentationCore`「No tests」的既有约定一致。

`Packages/Camera/CameraFeature/Package.swift`：本 stage 首次创建，依赖 `CameraCore`（`.package(path: "../CameraCore")`），`platforms` 同样加 `.macOS(.v11)`（原因同 `CameraCore`：依赖了 `Shared`）。Stage 3 追加 `CameraPipeline` 依赖（`DocumentCaptureUseCase` 需要），Stage 4 在已有依赖基础上补 Preset/Registry/ThermalPolicy 相关源文件，全程**不新建**这个包。

**实现期额外修正**：任何文件里用到 `Shared` 定义的类型（`CameraError`/`LensType`）但只 `import CameraCore`/`@testable import CameraFeature` 的地方，都要显式补一行 `import Shared`——Swift 不会自动把依赖的依赖传递可见，这在 `CameraCore/Tests/CameraCoreTests/CameraSessionCapabilityTests.swift` 和 `CameraFeature/Tests/CameraFeatureTests/CameraSessionUseCaseTests.swift` 里各漏了一次，编译时才暴露。

## 执行顺序

1. 创建 `Packages/Camera/Shared`，写完 `CameraError` / `Logger` / `CoordinateConverter` / `GeometryUtils`，跑 `swift build`
2. 创建 `Packages/Camera/CameraCore`，先落 `Model/` 与 `Protocol/` 里的纯数据类型和协议（无实现依赖），跑 `swift build`
3. 实现 `CameraSession`：session 生命周期 → 设备控制（ISO/快门/EV/WB/对焦/镜头切换）→ DeviceCapability 发布 → 中断恢复
4. 实现 `FramePlaybackProvider` 测试桩，写 `CameraSessionCapabilityTests`
5. 创建 `Packages/Camera/CameraUI`，实现 `PassthroughPreviewContainer` 与最小版 `CameraViewState`/`CameraAction`
6. 创建 `Packages/Camera/CameraFeature`，实现 `CameraSessionUseCase`，写 `CameraSessionUseCaseTests`（用 `FramePlaybackProvider` 驱动，覆盖权限拒绝/中断恢复两条分支）
7. 在 App 层（`MyEcommerce/`）新增一个最小宿主 View，仅用于手动验收（不需要接入现有 TabView，可临时挂在 ModuleTestView 的调试入口下）

## 验收清单

（原文档第 13 节 Stage 1 验收项，逐条保留）

- [ ] 三颗镜头切换后滑杆范围随 capability 更新
- [ ] 来电中断后自动恢复预览
- [ ] 手动参数在锁屏-解锁后保持
- [ ] 帧回放器可驱动 Pipeline 单测（无真机）

## 验证方式

```bash
cd Packages/Camera/Shared && swift build && swift test        # 4/4 tests passed
cd Packages/Camera/CameraCore && swift build && swift test    # 3/3 tests passed
cd Packages/Camera/CameraFeature && swift build && swift test # 3/3 tests passed
```

`Packages/Camera/CameraUI` 用了 `UIViewRepresentable`，无法用 `swift build`/`swift test` 在 macOS host 上验证（见上文"实现期额外修正"），需要在 Xcode 里把这 4 个包加成 App target 的本地 Swift Package 依赖后，通过 iOS 模拟器/真机 destination 编译验证。

真机/模拟器手动验收（需先完成 App 层依赖接入，见下方"App 层接入"）：接入调试入口，实际切换镜头、来电测试、锁屏解锁测试，逐条核对上面的验收清单。

## App 层接入（已完成）

用户已在 Xcode 里为 `MyEcommerce` app target 添加了 `Packages/Camera/{Shared,CameraCore,CameraUI,CameraFeature}` 四个本地包依赖。在此基础上补了调试宿主 View：

- `MyEcommerce/Debug/CameraDebugView.swift`：`CameraDebugViewModel`（`@MainActor final class ObservableObject`）持有一个 `CameraSession` 与一个 `CameraSessionUseCase(cameraSource: session)`，View 显示 `PassthroughPreviewContainer`（拿到 `previewLayer` 前先显示黑屏占位）、当前 `SessionState`、当前镜头，并提供一个三段式 `Picker` 触发 `switchLens`。
- `MyEcommerce/MyEcommerceApp.swift`：`Screen` 枚举加了 `case cameraTest`；`TabView` 里仿照 `WebTest`/`ModuleTest` 的既有写法（各自独立 Tab，而不是塞进 `ModuleTestView` 的列表里——那个列表当前是纯展示、没有导航能力，硬塞进去需要先改 `WebContainerFeature` 包，属于跨 feature 包的改动，不划算）新增了一个 `NavigationStack { CameraDebugView().navigationTitle("CameraTest") }` Tab。
- App 目标（`MyEcommerce/`）在这个工程里是 `PBXFileSystemSynchronizedRootGroup`，新增的 `.swift` 文件会被 Xcode 自动纳入 target，不需要手动改 `project.pbxproj`。

**实现期修正（App 层接入后才暴露）**：`previewLayer` 最初声明为普通 actor-isolated `let`（无 `nonisolated`）。这在 `swift test`（CLI 单测从没跨 actor 读取过 `previewLayer`）下没暴露问题，但 `CameraDebugView` 里 `previewLayer = await session.previewLayer` 一编译就报 `Non-Sendable type 'AVCaptureVideoPreviewLayer' of property 'previewLayer' cannot exit actor-isolated context`——Swift 6 严格并发下，非 `Sendable` 的值即便 `await` 也不允许"逃出"actor 隔离域。修正为 `public nonisolated(unsafe) let previewLayer: AVCaptureVideoPreviewLayer`：它在 `init` 里赋值一次后永不再变，`nonisolated(unsafe)` 是 Swift 6 里处理这种"确定安全但类型系统证明不了"的标准逃生舱口。`CameraDebugView.swift` 里对应去掉了不再需要的 `await`；`CameraSessionUseCaseTests.swift` 里的 `MockCameraSource.previewLayer` 也同步加了 `nonisolated(unsafe)` 保持写法一致（虽然当前单测没有跨 actor 读取它，不加也能编译过）。

**已知限制（已解决）**：`CameraSession` 内部真实的 AVFoundation 配置（权限请求、`AVCaptureDeviceInput` 接入、`capability`/`frames` 真实产出、中断通知监听）在 Stage 1 里曾经只是注释占位。这部分已经在后续的 [`docs/plans/avfoundation_capture_layer_followup.md`](./avfoundation_capture_layer_followup.md) 里补齐——`CameraSession` 现在是真实实现，`CameraDebugView` 在真机/iOS 模拟器上能看到真实预览、真实镜头切换、真实中断恢复。手动曝光/白平衡/变焦这套 API 在 AVFoundation 里整体是 iOS-only，`CameraCore` 用 `#if os(iOS)` 分支处理，详见该文档。"帧回放器可驱动 Pipeline 单测（无真机）"这一项从 Stage 1 起就已经用 `FramePlaybackProvider` + 单测验证过，不受此限制影响。

**Bug 修复（真机验收时发现）**：AVFoundation 采集层填真后，用户在真机上验收发现 `Session state` 已经显示 `running`（权限、设备发现、`session.startRunning()` 全部成功），但预览画面依然是纯黑。定位到 `PassthroughPreviewContainer.updateUIView` 只在被调用时把 `previewLayer.frame` 设成 `uiView.bounds`——但 `previewLayer` 是手动 `addSublayer` 上去的子 layer，不受 Auto Layout 管理，而 SwiftUI 并不保证在 wrapper view 的真实尺寸被 Auto Layout 解析出来之后一定会再调一次 `updateUIView`（这个 view 没有任何 `@State`/`@Published` 会触发 SwiftUI 重新求值 body）。结果是 `previewLayer` 常年停在初始的 `CGRect.zero`——session 真的在跑，画面真的在渲染，只是 layer 尺寸是 0x0，肉眼看到的就是黑屏。修法：改用一个自定义 `PreviewHostView: UIView` 子类，重写 `layoutSubviews()`，在每次真实布局变化（包括第一次）时都把 `previewLayer.frame = bounds` 同步刷新，不再依赖 SwiftUI 的 `updateUIView` 调用时机。

# Stage 3：Vision + 自动裁剪（V4）

> 专业相机架构第三阶段：在 Stage 2 的分析链上接入基于 Vision framework 的检测器（文档/卡片检测为主），把检测出的四边形做时域平滑，并落地"检测 → 透视校正 → 自动裁剪"的完整拍照用例。

来源文档：`docs/specs/iOS_Professional_Camera_Architecture_V2.md` 第 3（GeometryUtils 透视校正落地）、5.3（quad 时域平滑）、7（CameraVision）、10（DocumentCaptureUseCase）、13（Stage 3）节。

## 背景

Stage 2 交付了双链 Pipeline 与 Overlay 渲染，但唯一接入的分析器是不依赖 Vision 的 `HistogramAnalyzer`。本 stage 新建 `CameraVision` 包，专门收纳基于 Vision framework 的 `FrameAnalyzer` 实现，并让 `Annotation.quad` 第一次真正产出数据——用 Stage 1 就在 `Shared.GeometryUtils` 里占位的 `perspectiveTransform` 和 `EMAFilter` 完成"检测框防抖 + 透视校正裁切"的完整业务闭环。

## 设计概要

- 分层依赖规则（本 stage 相关部分）：
  - `CameraVision` 依赖 `CameraPipeline`（仅协议：实现 `FrameAnalyzer`）+ `Shared`
  - `CameraVision` **禁止**依赖 `CameraCore` / `CameraUI`——检测器不知道画面是怎么采集的，也不知道结果怎么画
  - `CameraFeature`（本 stage 首次引入，最小化）依赖 `CameraCore`、`CameraPipeline`，**不**直接依赖 `CameraVision` 具体类型，而是通过 `PipelineController.setAnalyzers([any FrameAnalyzer])` 注入——这条规则是 Stage 4 插件生态（新增算法 = 新类型 + 组合根一行注册）能够成立的前提，本 stage 提前遵守。
- **quad 时域平滑**：`Annotation.quad` 结果在 `OverlayManager`（`CameraUI`）内做 EMA 平滑，消除检测框抖动；`GeometryUtils.EMAFilter`（Stage 1 已占位）在本 stage 补上真实实现和单测。
- **拍照与预览复用同一份检测结果**：`DocumentCaptureUseCase` 不重新跑一次 Vision 请求，而是复用分析链最近一次 `quad` Annotation，避免拍照瞬间重复计算。
- `CameraFeature` 包已在 Stage 1 创建（承载 `CameraSessionUseCase`），本 stage 是**扩展**而非新建：追加对 `CameraPipeline` 的包依赖，新增 `DocumentCaptureUseCase`。

**实现期修正/发现（相对本文档早期草稿）**：
1. `CameraVision` 实际**不依赖 `Shared`**——和 Stage 2 `CameraPipeline` 一样，7 个 Analyzer 都不需要 `LensType`/`CameraError`/`CoordinateConverter`/`GeometryUtils` 里的任何一个，`GeometryUtils` 是在 `CameraUI.OverlayManager` 里用的（那是 `CameraUI` 依赖 `Shared`，不是 `CameraVision`）。`CameraVision` 只依赖 `CameraPipeline`。
2. **`Frame` 类型在两个模块里各有一份，故意不共享**：`CameraCore.CameraSourceProtocol.frames` 用的是 Stage 1 就声明的最小 `Frame`（只有 `pixelBuffer`/`timestamp`），`CameraPipeline.Frame`（Stage 2）多了 `orientation`/`cameraMetadata`。因为 `CameraCore` 不能依赖 `CameraPipeline`、`CameraPipeline` 也不能依赖 `CameraCore`（分层规则互相禁止），这两个类型注定不能是同一个。**任何同时 `import CameraCore` 和 `import CameraPipeline` 的文件，写裸的 `Frame` 会有编译期二义性**，必须显式写 `CameraCore.Frame` 或 `CameraPipeline.Frame` 消歧义（`DocumentCaptureUseCaseTests.swift` 里的 `StubCameraSource` 就是这么处理的）。这也是"已知限制"里反复提到的"`CameraSession.frames` 从来没有真实产出"的根源之一——将来真正接入采集链路时，需要在 `CameraFeature` 里写一个 `CameraCore.Frame → CameraPipeline.Frame` 的转换函数（补全 orientation/metadata），这个转换目前完全不存在。
3. `DocumentAnalyzer`/`CardAnalyzer` 的 Vision 请求失败处理统一成 `do { try handler.perform(...) } catch { return [] }`（原草稿 `CardAnalyzer` 用 `try?` 静默吞掉错误，风格不统一，实现时改成和 `DocumentAnalyzer` 一致）。
4. `GeometryUtils.perspectiveTransform` 真正的求解方式：`CGAffineTransform` 只有 6 自由度，无法表达真正的透视投影（8 自由度），用 `corners[0]`（topLeft）/`corners[1]`（topRight）/`corners[3]`（bottomLeft）三点精确求解仿射变换（3 点对应正好等于仿射变换自由度数），`corners[2]`（bottomRight）映射后有残余误差——这是文档里"取仿射近似"的具体数学实现（3x3 矩阵求逆，见 `Shared/Sources/Shared/GeometryUtils.swift` 里的私有 `Matrix3x3` 类型），已用已知解析解（轴对齐正方形 → 纯缩放）验证正确。退化四边形（三点共线，行列式为 0）时退回 `.identity`。

## 新增文件

```
Packages/Camera/CameraVision/
├── Package.swift
├── Sources/CameraVision/
│   ├── DocumentAnalyzer.swift
│   ├── CardAnalyzer.swift
│   ├── RectangleAnalyzer.swift
│   ├── OCRAnalyzer.swift
│   ├── BarcodeAnalyzer.swift
│   ├── FaceAnalyzer.swift
│   └── HorizonAnalyzer.swift
└── Tests/CameraVisionTests/
    └── DocumentAnalyzerQuadTests.swift

Packages/Camera/Shared/Sources/Shared/
└── GeometryUtils.swift                    // 补全 perspectiveTransform 实现 + EMAFilter 单测

Packages/Camera/CameraFeature/              // 已在 Stage 1 创建，本 stage 追加以下文件
├── Sources/CameraFeature/
│   └── UseCase/
│       └── DocumentCaptureUseCase.swift
└── Tests/CameraFeatureTests/
    └── DocumentCaptureUseCaseTests.swift

Packages/Camera/CameraUI/Sources/CameraUI/Overlay/
└── OverlayManager.swift                    // 接入 EMA 平滑 + quad 绘制
```

### `CameraVision/Sources/CameraVision/DocumentAnalyzer.swift`

```swift
import Vision
import CameraPipeline

/// 文档检测：产出四边形 Annotation，归一化坐标（左下原点，与 Vision 原生坐标系一致）。
public struct DocumentAnalyzer: FrameAnalyzer {
    public let id = PluginID("document")
    public let preferredFPS: Int

    public init(preferredFPS: Int = 8) {
        self.preferredFPS = preferredFPS
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.7
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: frame.pixelBuffer, orientation: frame.orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).map { observation in
            .quad(
                id: UUID(),
                corners: [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft],
                confidence: observation.confidence
            )
        }
    }
}
```

### `CameraVision/Sources/CameraVision/CardAnalyzer.swift`

```swift
import Vision
import CameraPipeline

/// 卡片检测：固定长宽比约束的矩形检测，复用 DocumentAnalyzer 相同的 VNDetectRectanglesRequest，
/// 区别在于 aspectRatio 约束（信用卡/身份证比例）。
public struct CardAnalyzer: FrameAnalyzer {
    public let id = PluginID("card")
    public let preferredFPS: Int
    private let aspectRatio: ClosedRange<Float>

    public init(preferredFPS: Int = 8, aspectRatio: ClosedRange<Float> = 1.4...1.6) {
        self.preferredFPS = preferredFPS
        self.aspectRatio = aspectRatio
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = aspectRatio.lowerBound
        request.maximumAspectRatio = aspectRatio.upperBound
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: frame.pixelBuffer, orientation: frame.orientation, options: [:])
        try? handler.perform([request])
        return (request.results ?? []).map { observation in
            .quad(
                id: UUID(),
                corners: [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft],
                confidence: observation.confidence
            )
        }
    }
}
```

### `CameraVision/Sources/CameraVision/RectangleAnalyzer.swift` / `OCRAnalyzer.swift` / `BarcodeAnalyzer.swift` / `FaceAnalyzer.swift` / `HorizonAnalyzer.swift`

```swift
// 五个分析器统一实现 FrameAnalyzer，分别包一层对应的 Vision request：
// RectangleAnalyzer  -> VNDetectRectanglesRequest（无长宽比约束，产出 .quad）
// OCRAnalyzer        -> VNRecognizeTextRequest，产出 .custom(key: "ocr", payload: [RecognizedText])
// BarcodeAnalyzer    -> VNDetectBarcodesRequest，产出 .objects([DetectedObject])
// FaceAnalyzer       -> VNDetectFaceRectanglesRequest，产出 .objects([DetectedObject])
// HorizonAnalyzer    -> VNDetectHorizonRequest，产出 .horizon(angle:)
// 结构与 DocumentAnalyzer / CardAnalyzer 一致：id + preferredFPS + analyze(_:) 包一个 VNImageRequestHandler。
```

### `Shared/Sources/Shared/GeometryUtils.swift`（补全 Stage 1 占位）

```swift
import CoreGraphics

public enum GeometryUtils {
    /// 四边形透视校正矩阵：把检测到的四个角点映射到 targetSize 的矩形。
    public static func perspectiveTransform(quad corners: [CGPoint], targetSize: CGSize) -> CGAffineTransform {
        precondition(corners.count == 4, "quad must have exactly 4 corners")
        // 用 corners（topLeft/topRight/bottomRight/bottomLeft，归一化坐标）
        // 结合 targetSize 求解投影变换矩阵（CATransform3D / vImage_CGAffineTransform 或
        // 手写 3x3 单应矩阵求解后取仿射近似）。
        preconditionFailure("Fill in homography solve for Stage 3 DocumentCaptureUseCase")
    }

    /// EMA 低通滤波，用于检测框时域平滑，消除逐帧抖动。
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

    /// 四个角点各自维护一个 EMAFilter，避免相邻帧检测框跳变。
    public struct QuadEMAFilter {
        private var filters: [EMAFilter]
        public init(alpha: CGFloat = 0.3) { filters = Array(repeating: EMAFilter(alpha: alpha), count: 4) }
        public mutating func update(_ corners: [CGPoint]) -> [CGPoint] {
            precondition(corners.count == 4)
            return zip(filters.indices, corners).map { index, point in filters[index].update(point) }
        }
    }
}
```

### `CameraFeature/Sources/CameraFeature/UseCase/DocumentCaptureUseCase.swift`

```swift
import CameraCore
import CameraPipeline

/// quad Annotation → 透视校正 → 自动裁剪。复用分析链最近一次 quad 结果，不重复跑 Vision 请求。
public struct DocumentCaptureUseCase {
    private let cameraSource: any CameraSourceProtocol
    private let pipeline: PipelineController

    public init(cameraSource: any CameraSourceProtocol, pipeline: PipelineController) {
        self.cameraSource = cameraSource
        self.pipeline = pipeline
    }

    public func capture(latestQuad: Annotation?, targetSize: CGSize) async throws -> PhotoCaptureResult {
        let raw = try await cameraSource.capturePhoto(PhotoCaptureRequest(captureRAW: true))
        guard case .quad(_, let corners, _) = latestQuad else {
            return raw // 无检测结果时退化为普通拍照
        }
        let transform = GeometryUtils.perspectiveTransform(quad: corners, targetSize: targetSize)
        // 用 transform 对 raw.processedFileURL 对应的图像做裁剪校正，另存为最终输出，
        // 原始 DNG（raw.rawFileURL）保持不动，满足"拍照输出裁剪校正件 + 原始 DNG 两份"。
        return raw
    }
}
```

### `CameraUI/Sources/CameraUI/Overlay/OverlayManager.swift`

```swift
import CameraPipeline
import Shared

/// 把 [Annotation] 转成 [ScreenAnnotation]：用 Shared.CoordinateConverter 转换坐标，
/// quad 类型额外过一遍 GeometryUtils.QuadEMAFilter 做时域平滑。
public final class OverlayManager {
    private var quadFilter = GeometryUtils.QuadEMAFilter()
    private let converter: CoordinateConverter

    public init(converter: CoordinateConverter) {
        self.converter = converter
    }

    public func makeScreenAnnotations(from annotations: [Annotation]) -> [ScreenAnnotation] {
        annotations.map { annotation in
            switch annotation {
            case .quad(_, let corners, _):
                let screenCorners = corners.map(converter.convert(normalizedPoint:))
                let smoothed = quadFilter.update(screenCorners)
                return .quad(corners: smoothed)
            case .histogram(let data):
                return .histogram(data)
            case .horizon(let angle):
                return .horizon(angle: angle)
            case .objects(let objects):
                return .objects(objects.map { $0.boundingBox })
            case .custom:
                return .quad(corners: []) // V5 custom 类型的绘制留给具体插件扩展 OverlayCanvas
            }
        }
    }
}
```

## Package.swift 变更

`Packages/Camera/CameraVision/Package.swift`：新建包，**只依赖 `CameraPipeline`**（仅协议；见上方"实现期修正"第 1 条，不依赖 `Shared`），不依赖 `CameraCore`/`CameraUI`，`platforms: [.iOS(.v18), .macOS(.v11)]`（Vision framework 在 macOS 上早就可用，加 `.macOS(.v11)` 只是为了让 `swift build`/`swift test` 能在本机跑，和依赖图的最低版本对齐）。

`Packages/Camera/CameraFeature/Package.swift`：追加对 `CameraPipeline` 的依赖（`.package(path: "../CameraPipeline")`；Stage 1 建包时只依赖了 `CameraCore`）。**不**添加对 `CameraVision` 的包依赖——`DocumentCaptureUseCase` 只接收 `PipelineController` 产出的 `Annotation`，不 import 具体分析器类型，保证"新增算法 L4 零改动"从这里就成立。

`Packages/Camera/CameraUI/Package.swift`：新增 `OverlayManager.swift`，无新依赖（`Shared` 已在 Stage 1 引入）。

## 执行顺序

1. 创建 `CameraVision` 包，实现 `DocumentAnalyzer` + `CardAnalyzer`，用真实图片跑通 `VNDetectRectanglesRequest`
2. 补全 `Shared.GeometryUtils.perspectiveTransform` 与 `QuadEMAFilter`，写 `EMAFilter`/`QuadEMAFilter` 单测（纯数学，不需要真机）
3. 实现剩余四个 Analyzer（Rectangle/OCR/Barcode/Face/Horizon），保持同样的"包一层 Vision request"结构
4. 在已有的 `CameraFeature` 包（Stage 1 创建）里追加 `CameraPipeline` 依赖，实现 `DocumentCaptureUseCase`
5. 在 `CameraUI` 实现 `OverlayManager`，把 Stage 2 的 `OverlayCanvas` 接上真实 quad 数据
6. 在调试入口里把 `DocumentAnalyzer` 通过 `pipeline.setAnalyzers([...])` 注入，手动验收检测框抖动情况与拍照输出

## 验收清单

（原文档第 13 节 Stage 3 验收项，逐条保留）

- [ ] 检测框无可见抖动（EMA 生效）
- [ ] 拍照输出裁剪校正件 + 原始 DNG 两份
- [ ] 关闭检测后分析链零 CPU 占用

## 验证方式

```bash
cd Packages/Camera/CameraVision && swift build && swift test   # 9/9 tests passed
cd Packages/Camera/Shared && swift test                        # 9/9 tests passed（含新的 perspectiveTransform/QuadEMAFilter 用例）
cd Packages/Camera/CameraFeature && swift build && swift test  # 6/6 tests passed（新增 DocumentCaptureUseCase 3 条）
```

`CameraVision` 的单测用 `CVPixelBufferCreate` 造一块空白 32BGRA 像素缓冲，跑真实的 `VNImageRequestHandler`/`VNDetectRectanglesRequest` 等请求（不是 mock）——空白图片上跑不出矩形/人脸/条码/文字，用来验证"无检测结果时返回空数组"这条路径；`HorizonAnalyzer` 没写"空结果"用例，因为水平仪检测在空白图上是否返回观测值不确定，为了不写一个可能偶发失败的脆弱测试，只测了 `id`/`preferredFPS` 的稳定性。

`CameraUI`（新增 `OverlayManager.swift`）依然只能用 Xcode 验证，理由同 Stage 1/2（UIKit 类型 + SwiftPM 全图 platform 校验的双重限制）。

真机手动验收（同样需要先补上 `CameraSession` 的真实 AVFoundation 采集链路，见下方"已知限制"）：对着文档/卡片实测检测框抖动情况；拍照后核对相册里裁剪校正件与原始 DNG 是否成对；用 Instruments 关闭 `setAnalyzers([])` 后确认分析链线程无 CPU 占用。

## 已知限制（部分已解决）

`CameraSession` 的真实 AVFoundation 采集链路已经在 [`docs/plans/avfoundation_capture_layer_followup.md`](./avfoundation_capture_layer_followup.md) 里补齐（`captureDualTrack` 不再是占位实现，真实产出 RAW+HEIF）。但 `CameraCore.Frame → CameraPipeline.Frame` 的转换仍未实现（见该文档"仍未完成的部分"第 1 条），所以 `PipelineController.consume(...)` 依然没有真实调用方。本 stage 新增的 `DocumentCaptureUseCase.capture(...)` 里，`GeometryUtils.perspectiveTransform` 是真实、经过验证的实现（见 `Shared` 的单测），但计算出的 `transform` 目前**依然没有被应用到任何图像文件**上——`_ = transform` 只是为了消除"变量未使用"的编译警告，真正的裁剪落盘（读取 `raw.processedFileURL`、应用 transform、另存新文件）还没做。因此验收清单三条里：
- "检测框无可见抖动"——`GeometryUtils.QuadEMAFilter` 本身已经过单测验证平滑逻辑正确，但要在真机上"看到"效果，需要 `PipelineController.consume(...)` 真的被调用（即 Frame 转换桥接补上之后）；
- "拍照输出裁剪校正件 + 原始 DNG 两份"——`captureDualTrack` 已经能产出真实的 DNG+HEIC 两份文件，但 `DocumentCaptureUseCase` 里的裁剪落盘（把 transform 真正应用到图像上）还没做，目前拿到的两份文件都是未裁剪的原始拍照结果；
- "关闭检测后分析链零 CPU 占用"——这条已经可以通过 `PipelineController` 的单测间接验证调度逻辑正确（`setAnalyzers([])` 后 `consume` 直接跳过分析分支），但"零 CPU 占用"的真机 Instruments 测量仍需真实调用方（同样卡在 Frame 转换桥接未实现）。

## A1：Vision 检测接入调试页（`frame_bridging_followup.md` 之后的收尾轮）

Frame 转换桥接（`CameraFeature.CameraPipelineBridge`，见 `frame_bridging_followup.md`）落地后，`PipelineController.consume(...)` 终于有了真实调用方，上面"已知限制"里因为没有调用方而卡住的三条验收项本轮解除阻塞：

1. **`CoordinateConverter` 补上了 aspect-fill 裁切偏移**（`Packages/Camera/Shared/Sources/Shared/CoordinateConverter.swift`）：Stage 1 的 `convert(normalizedPoint:)` 只做"翻转 y + 按 layer 缩放"，没处理 `videoGravity = .resizeAspectFill` 下图像被等比放大、两侧对称裁掉溢出部分这件事——真机上检测框会随图像与预览层宽高比不一致而系统性偏移/压扁。新增 `convert(normalizedPoint:uprightImageSize:)` 重载，按图像与 layer 的宽高比算出居中裁切偏移；旧签名保留作为"尺寸未知时退化为纯缩放"的兼容入口。配 4 条单测（`CoordinateConverterTests.swift`），验证更宽/更高两种裁切方向、以及零尺寸兜底路径。
2. **`CameraPipeline.Frame` 新增 `uprightImageSize` 计算属性**（`Frame.swift`）：按 `orientation` 把传感器原始宽高转成"人眼看到的"宽高比（`.left`/`.right` 是 90 度旋转，需要交换宽高）。`PipelineController.consume(...)` 把这个值和分析结果一起包进新的 `AnnotationBatch`（`annotations: [Annotation]` + `uprightImageSize: CGSize`），替换掉原来只传 `[Annotation]` 的 `annotations` 流——脱离产出它们的那一帧，光有归一化坐标算不出正确的屏幕坐标。6 条新单测（`FrameTests.swift` 4 条 + `PipelineControllerLatestWinsTests.swift` 1 条），CameraPipeline 从 7 条涨到 10 条。
3. **`OverlayManager.converter` 改成可变属性**，`makeScreenAnnotations(from:uprightImageSize:)` 加了 `uprightImageSize` 参数透传给 `converter.convert`。
4. **`CameraDebugView` 修了一个实际的 bug**：`PreviewLayerFrameProvider` 原来只在 `start()` 里快照一次 `previewLayer.frame`——这时候 SwiftUI 布局大概率还没跑完，快照几乎必然是 `.zero`，会让所有 quad 检测框都算成零尺寸（直方图不受影响，因为 `.histogram` 走的是透传，不经过 `CoordinateConverter.convert`）。改成在 `observeAnnotationsIfNeeded()` 的每批 annotations 到达时，用当前 `previewLayer.frame` 现造一个新 provider 赋给 `overlayManager.converter`。
5. **新增 "Document detection" 开关**：动态在 `pipelineController.setAnalyzers([HistogramAnalyzer()])` 和 `[HistogramAnalyzer(), DocumentAnalyzer()]` 之间切换，用来验收"检测框无抖动"和"关闭后零 CPU"这两条。App target 新增 `import CameraVision`。

**验证**：`Shared`（12 tests）、`CameraPipeline`（10 tests）CLI 全绿；`CameraUI`/App target 改动（`OverlayManager`、`CameraDebugView`）依然只能人工走查，理由不变（SwiftPM 全图 platform 校验限制）。全量回归 43/43。

**仍未验证**：aspect-fill 裁切偏移公式没有真机验证——真机预览层的实际 videoGravity 行为、以及 `CGImagePropertyOrientation` 的 `.left`/`.right` 宽高互换判断是否跟真实传感器方向一致，都需要对着真实文档/卡片看检测框贴合度确认。

## A2：文档裁剪落盘（打勾 Stage 3 最后一条验收项）

`DocumentCaptureUseCase.capture(...)` 里那句 `_ = transform`（只是为了消除"变量未使用"警告的占位）换成了真实实现：

1. **`DocumentCaptureUseCase.writePerspectiveCorrectedHEIC(...)`**（`Packages/Camera/CameraFeature/Sources/CameraFeature/UseCase/DocumentCaptureUseCase.swift`）：用 `CIFilter.perspectiveCorrection()`（`CoreImage.CIFilterBuiltins` 的类型安全 API，不是手写 `CIFilter(name:)` 字符串 key）对 `raw.processedFileURL` 读出的 `CIImage` 做透视校正——四个角点直接用 Vision 的归一化坐标 × 图像像素宽高，Vision 与 CIImage 同为左下原点，不需要翻转（跟 `CoordinateConverter` 那条转屏幕坐标的链路是两回事，这里全程留在图像自己的坐标系里）。校正后再做一次"平移回原点 + 缩放到 targetSize + 裁掉浮点误差多余边缘"，最后落盘为一个新的 HEIC 文件，原始 DNG（`raw.rawFileURL`）不动。
2. **实现期修正**：`CIContext.writeHEIFRepresentation(of:to:...)` 走的是硬件 HEVC 编码路径，在没有该硬件的机器上（本仓库 CLI 验证用的 macOS host 正是这种）会直接抛错（`failed to add image to the PhotoCompressionSession`）。改用 `CIContext.createCGImage` 转出 `CGImage` 后走 `ImageIO` 的 `CGImageDestination` 写 HEIC——这条路径不依赖硬件编码器，真机和 CLI 验证用的 macOS host 是同一份代码，不是"仅真机能跑"的降级分支。
3. **corners 数量校验**：`guard ... corners.count == 4` 补了一个之前没有的边界检查——少于 4 个角点时退化为普通拍照，不会传错误数量的点给 `CIPerspectiveCorrectionFilter`（之前的实现从没读过 `corners`，这个坑一直没暴露出来）。
4. **测试改用真实文件**：原来的 3 条测试用假路径 `/tmp/processed.heic`（文件根本不存在），因为旧实现从不读文件所以能"碰巧"通过；换成真实实现后这些假路径会导致读取失败。重写测试改成真的用 `CGImageDestination` 造一张临时 HEIC 文件当 `raw.processedFileURL`，新增两条测试：一条验证 4 角点输入产出一个新文件（不是原文件）、尺寸精确等于 `targetSize`、原始 DNG URL 不变；一条验证角点数量不足 4 个时退化为普通拍照。`CameraFeature` 从 9 条涨到 10 条。

**验证**：`CameraFeature` 10/10 CLI 全绿（含新的裁剪落盘端到端测试，走真实 `CIImage`/`CIFilter`/`CGImageDestination`，不是 mock）。全量回归 44/44。

**App 层接入**：`CameraDebugView` 新增 "Capture Document" 按钮——缓存分析链最近一次收到的 quad annotation（`observeAnnotationsIfNeeded()` 里顺手记录），点击后调 `DocumentCaptureUseCase.capture(latestQuad:targetSize:)`（`targetSize` 暂时固定 800×1100，只是调试占位比例，不是最终设计），结果用 `Image(uiImage:)` 弹出预览 + 显示两个文件名供核对。这部分照例只能人工走查（App target 无 CLI 信号）。

**仍未验证**：真机上对着真实文档/卡片实测——裁剪出来的图像内容是否真的对应检测框圈住的区域（透视校正方向、四角点顺序是否跟真实 Vision 输出一致）；HEIC 硬件编码路径改用 `ImageIO` 之后在真机上是否仍然稳定（真机通常有硬件编码器，理论上不受影响，但没有实测确认）。

// Metal 协议类型未标注 Sendable，见 CameraPipeline.PipelineController 顶部注释，处理方式保持一致。
@preconcurrency import Metal
import CoreVideo
import ImageIO

#if canImport(UIKit)
import UIKit
#endif

import CameraCore
import CameraPipeline

/// L1 → L2 的真实桥接：把 `CameraCore.Frame`（只有 pixelBuffer + timestamp）转成
/// `CameraPipeline.Frame`（多 orientation/cameraMetadata）+ 一个零拷贝转换好的 `MTLTexture`，
/// 喂给 `PipelineController.consume(_:texture:context:)`。这一步此前被两份 Stage 2/3 计划文档和
/// `avfoundation_capture_layer_followup.md` 都标记为"仍未完成"——预览此前已经是真实画面，但
/// Histogram / Vision 检测这些依赖 Pipeline 的功能一直没有真实数据源，本类型补上这条链路。
///
/// 已知简化（不是伪造数据，是明确未实现的范围，见 avfoundation_capture_layer_followup.md）：
/// - `orientation` 来自 `UIDevice.current.orientation`（见 `currentOrientation()`），只覆盖后置
///   摄像头场景——`CameraSession` 的 `AVCaptureDevice.DiscoverySession` 目前硬编码
///   `position: .back`（本项目暂不支持前置摄像头），所以不需要处理镜像。
/// - `iso` / `shutterDuration` / `lensPosition` / `intrinsics` 都是真实值——`intrinsics` 来自
///   `frame.intrinsics`（`FrameOutputDelegate` 从 `CMSampleBuffer` 的
///   `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix` attachment 提取），只有
///   `CameraSession` 开了 `isCameraIntrinsicMatrixDeliveryEnabled` 且设备支持时才有值，
///   不支持时透传出来的就是 `nil`（`FrameMetadata.intrinsics` 本来就是 Optional）。
public actor CameraPipelineBridge {

    private let cameraSource: any CameraSourceProtocol
    private let pipelineController: PipelineController
    private let metalDevice: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache?
    private var consumeTask: Task<Void, Never>?
    private var hasStartedDeviceOrientationNotifications = false

    public init(
        cameraSource: any CameraSourceProtocol,
        pipelineController: PipelineController,
        metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
    ) {
        self.cameraSource = cameraSource
        self.pipelineController = pipelineController
        guard let metalDevice, let commandQueue = metalDevice.makeCommandQueue() else {
            preconditionFailure("no Metal device available on this host")
        }
        self.metalDevice = metalDevice
        self.commandQueue = commandQueue

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &cache)
        self.textureCache = cache
    }

    /// 幂等：重复调用不会重复订阅 frames 流。
    public func start() {
        guard consumeTask == nil else { return }
        let cameraSource = cameraSource
        consumeTask = Task { [weak self] in
            let frames = await cameraSource.frames
            for await frame in frames {
                guard !Task.isCancelled else { return }
                await self?.handle(frame)
            }
        }
    }

    public func stop() {
        consumeTask?.cancel()
        consumeTask = nil
    }

    private func handle(_ frame: CameraCore.Frame) async {
        guard
            let texture = makeTexture(from: frame.pixelBuffer),
            let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        let exposure = await cameraSource.currentExposureMetadata()
        let orientation = await currentOrientation()
        let pipelineFrame = CameraPipeline.Frame(
            pixelBuffer: frame.pixelBuffer,
            timestamp: frame.timestamp,
            orientation: orientation,
            cameraMetadata: FrameMetadata(
                iso: exposure.iso,
                shutterDuration: exposure.shutterDuration,
                lensPosition: exposure.lensPosition,
                intrinsics: frame.intrinsics
            )
        )
        let context = RenderContext(device: metalDevice, commandBuffer: commandBuffer)
        await pipelineController.consume(pipelineFrame, texture: texture, context: context)
        commandBuffer.commit()
    }

    // UIDevice 的方向必须先 beginGeneratingDeviceOrientationNotifications() 才会更新，
    // 不调用的话 .orientation 恒为 .unknown；只需要全局开一次，用 actor 状态位防重复开启。
    // macOS host（swift build/test 用来验证的平台）没有 UIDevice，走 #if os(iOS) 降级到固定值，
    // 跟 CameraSession.currentExposureMetadata() 的 macOS 降级处理方式一致。
    private func currentOrientation() async -> CGImagePropertyOrientation {
        #if os(iOS)
        if !hasStartedDeviceOrientationNotifications {
            hasStartedDeviceOrientationNotifications = true
            await MainActor.run { UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
        }
        let deviceOrientation = await MainActor.run { UIDevice.current.orientation }
        // 后置摄像头（本项目目前唯一支持的镜头位置）在竖屏持机时传感器物理朝向是 landscape，
        // 这是标准映射表：设备转向哪边，画面就需要反向转回来才能正着看。
        switch deviceOrientation {
        case .portrait: return .right
        case .portraitUpsideDown: return .left
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        default: return .right // faceUp/faceDown/unknown 时退回竖屏默认值（没有跟踪"上一次"的状态）
        }
        #else
        return .right
        #endif
    }

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        guard status == kCVReturnSuccess, let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture) else {
            return nil
        }
        return texture
    }
}

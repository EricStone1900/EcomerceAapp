import AVFoundation
@preconcurrency import Metal
import SwiftUI

import CameraCore
import CameraFeature
import CameraPipeline
import Shared

/// `CALayerFrameProviding` 要求 `Sendable`，而 `AVCaptureVideoPreviewLayer` 是非 `Sendable` 的
/// UIKit 类，不能直接持有它的引用——只快照一次 `.frame` 的值（`CGRect` 本身就是 `Sendable`）。
/// 这个快照必须在每批 annotations 到达时用当前 `previewLayer.frame` 现造一个新实例（见
/// `observeAnnotationsIfNeeded`），不能只在 `start()` 里造一次——那时候 SwiftUI 布局大概率
/// 还没跑完（同样的坑见 `docs/plans/stage3_camera_vision_plan.md` A1 节的实现期修正）。
private struct PreviewLayerFrameProvider: CALayerFrameProviding {
    let layerFrame: CGRect
}

/// 正式相机页面的 ViewModel（"Store"）：把 `CameraAction` 映射到具体的相机控制/Preset 应用/拍照，
/// 把 `CameraFeatureContext` 里各条流（capability/annotations/thermal）聚合成单向的
/// `CameraViewState` 供 `CameraView` 订阅。业务逻辑本身（clamp、插件解析、热降级、透视裁剪）
/// 全部已经在 `CameraFeature` 里实现并测试过，这里只是把它们接起来发布成 SwiftUI 状态——
/// 这个类型本身住在 `CameraUI`（不是 `CameraFeature`），因为它需要产出 `CameraUI.CameraViewState`
/// 这个只有 `CameraUI` 才有的类型，而 `CameraFeature` 不能反过来依赖 `CameraUI`（会形成循环依赖）。
/// 无法通过 CLI 验证（`CameraUI` 只声明 `platforms: [.iOS(.v18)]`，从来没有 macOS 支持），
/// 但它依赖的 `CameraFeatureContext` 里每一个 UseCase 都已经在 `CameraFeature` 有真实测试覆盖，
/// 这里的"未测试面"被刻意压缩到只剩接线本身。
@MainActor
public final class CameraViewModel: ObservableObject {

    @Published public private(set) var state: CameraViewState?
    @Published public private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    @Published public private(set) var sessionState: SessionState = .idle
    @Published public private(set) var lastDocumentCapture: PhotoCaptureResult?
    @Published public private(set) var captureErrorMessage: String?

    public var renderedFrames: AsyncStream<MTLTexture> { context.pipeline.renderedFrames }

    private let context: CameraFeatureContext
    private let sessionUseCase: CameraSessionUseCase
    private let presetsByID: [PresetID: CameraPreset]
    private var overlayManager: OverlayManager?
    private var latestCapability: DeviceCapability?
    private var latestQuad: Annotation?

    private var capabilityTask: Task<Void, Never>?
    private var annotationTask: Task<Void, Never>?
    private var thermalTask: Task<Void, Never>?

    public init(context: CameraFeatureContext, presets: [CameraPreset] = [.document, .portrait, .food, .night]) {
        self.context = context
        self.sessionUseCase = CameraSessionUseCase(cameraSource: context.session)
        self.presetsByID = Dictionary(uniqueKeysWithValues: presets.map { ($0.name, $0) })
    }

    public func start() async {
        previewLayer = context.session.previewLayer
        await sessionUseCase.start()
        sessionState = await sessionUseCase.state

        overlayManager = OverlayManager(
            converter: CoordinateConverter(previewLayer: PreviewLayerFrameProvider(layerFrame: previewLayer?.frame ?? .zero))
        )

        observeCapabilityIfNeeded()
        observeAnnotationsIfNeeded()
        observeThermalIfNeeded()
    }

    public func send(_ action: CameraAction) async {
        switch action {
        case .setISO(let iso):
            try? await context.session.apply(.setISO(iso))
        case .setShutter(let duration):
            try? await context.session.apply(.setShutter(duration))
        case .setEV(let bias):
            try? await context.session.apply(.setExposureBias(bias))
        case .setWB(let gains):
            try? await context.session.apply(.setWhiteBalance(gains))
        case .focus(let point):
            try? await context.session.apply(.focus(at: point))
        case .switchLens(let lens):
            try? await context.session.apply(.switchLens(lens))
        case .applyPreset(let presetID):
            await applyPreset(presetID)
        case .capture:
            await capture()
        }
    }

    private func applyPreset(_ presetID: PresetID) async {
        guard let preset = presetsByID[presetID], let capability = latestCapability else { return }
        let result = await context.presetUseCase.apply(preset, capability: capability)
        mutateState { viewState in
            viewState.activePreset = presetID
            viewState.manual = result.clamped.manual ?? viewState.manual
            // Stage 2 定义的规则：processors 非空就该看 Processed 预览。
            viewState.previewMode = result.processorCount > 0 ? .processed : .passthrough
        }
    }

    /// targetSize 暂时固定——正式的尺寸选择（比如按 Preset 或用户设置决定输出比例）不在本轮范围内，
    /// 跟 `CameraDebugView` 里 "Capture Document" 按钮当初的简化是同一个理由。
    private func capture() async {
        do {
            let result = try await context.documentCaptureUseCase.capture(
                latestQuad: latestQuad, targetSize: CGSize(width: 1200, height: 1600)
            )
            lastDocumentCapture = result
            captureErrorMessage = nil
        } catch {
            captureErrorMessage = "\(error)"
        }
    }

    private func observeCapabilityIfNeeded() {
        guard capabilityTask == nil else { return }
        let session = context.session
        capabilityTask = Task { [weak self] in
            for await capability in session.capability {
                guard let self else { return }
                self.latestCapability = capability
                if self.state == nil {
                    self.state = CameraViewState(capability: capability, manual: ManualSettings())
                } else {
                    self.mutateState { $0.capability = capability }
                }
            }
        }
    }

    private func observeAnnotationsIfNeeded() {
        guard annotationTask == nil else { return }
        let pipeline = context.pipeline
        annotationTask = Task { [weak self] in
            for await batch in pipeline.annotations {
                guard let self else { return }
                if let quad = batch.annotations.first(where: {
                    if case .quad = $0 { return true } else { return false }
                }) {
                    self.latestQuad = quad
                }
                guard let overlayManager = self.overlayManager else { continue }
                overlayManager.converter = CoordinateConverter(
                    previewLayer: PreviewLayerFrameProvider(layerFrame: self.previewLayer?.frame ?? .zero)
                )
                let screenAnnotations = overlayManager.makeScreenAnnotations(
                    from: batch.annotations, uprightImageSize: batch.uprightImageSize
                )
                self.mutateState { $0.annotations = screenAnnotations }
            }
        }
    }

    private func observeThermalIfNeeded() {
        guard thermalTask == nil else { return }
        let thermalObserver = context.thermalObserver
        thermalTask = Task { [weak self] in
            for await forcePassthrough in thermalObserver.shouldForcePassthrough {
                guard let self, forcePassthrough else { continue }
                self.mutateState { $0.previewMode = .passthrough }
            }
        }
    }

    /// `state` 在第一次 capability 到达前是 nil（`CameraViewState.capability` 是必填字段，没有
    /// 可以诚实填充的默认值），这期间的变更静默丢弃——annotations/thermal 事件理论上不会在
    /// capability 之前到达（session 必须先配置好才有 frame 流），但防御性地处理一下更安全。
    private func mutateState(_ mutate: (inout CameraViewState) -> Void) {
        guard var current = state else { return }
        mutate(&current)
        state = current
    }
}

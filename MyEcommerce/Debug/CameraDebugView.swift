import AVFoundation
@preconcurrency import Metal
import SwiftUI
import UIKit

import CameraCore
import CameraFeature
import CameraPipeline
import CameraUI
import CameraVision
import Shared

/// CALayerFrameProviding 要求 Sendable，而 AVCaptureVideoPreviewLayer 是非 Sendable 的 UIKit 类，
/// 不能直接持有它的引用；这里只快照一次 .frame 的值（CGRect 本身就是 Sendable）。这个快照必须
/// 在每批 annotations 到达时用当前 previewLayer.frame 现造一个新实例塞进
/// `OverlayManager.converter`——如果只在 start() 里造一次，那时候 SwiftUI 布局大概率还没跑完，
/// previewLayer.frame 几乎必然是 .zero，会让所有 quad 检测框都算成零尺寸（历史 bug，见
/// docs/plans/stage3_camera_vision_plan.md 实现期修正）。
private struct PreviewLayerFrameProvider: CALayerFrameProviding {
    let layerFrame: CGRect
}

/// Stage 1 手动验收用的调试宿主 View：驱动 CameraSessionUseCase 启动会话，
/// 用 PassthroughPreviewContainer 显示原始预览，暴露镜头切换按钮方便真机验收。
///
/// CameraSession 现在是真实的 AVFoundation 实现（权限请求 / 设备发现与接入 / 能力发布 /
/// 中断通知监听 / RAW+HEIF 双轨拍照），在真机或 iOS 模拟器上运行本页可以看到真实预览画面、
/// 真实的镜头切换、以及来电/切后台等中断后的自动恢复。手动曝光/白平衡/变焦这套 AVFoundation
/// API 整体是 iOS-only（Mac 摄像头没有对应能力），因此这部分逻辑只在 iOS 上生效，
/// `Packages/Camera/CameraCore` 在 macOS host 上 `swift build`/`swift test` 时会走
/// `#if os(iOS)` 的降级分支（详见 `CameraSession.swift`）。
///
/// Frame bridging（见 `docs/plans/frame_bridging_followup.md`）接入后，本页新增一个
/// Passthrough/Processed 预览切换：Processed 模式走真实的 CameraCore.Frame → CameraPipeline.Frame
/// 桥接（`CameraFeature.CameraPipelineBridge`）→ `PipelineController` → `ProcessedPreviewContainer`
/// 的完整链路，用来肉眼验收"Pipeline 真的收到了真实帧"这件事——切到 Processed 应该也能看到
/// 实时画面（经过一次 CVMetalTextureCache 零拷贝 + CIContext 转描的路径，理论上和 Passthrough
/// 看起来几乎一样，只是多绕了一圈 Pipeline）。同时挂了 HistogramAnalyzer（真实 vImage 统计，
/// 不再是占位）作为分析链验证，"Annotations received" 计数证明分析链在真的跑，屏幕底部叠加的
/// OverlayCanvas 直接画出真实的 RGB/luminance 直方图曲线——不受 Passthrough/Processed 切换影响，
/// 因为 CameraPipelineBridge 从 start() 起就在消费 cameraSource.frames。
///
/// "Document detection" 开关（Stage 3 收尾）动态把 `CameraVision.DocumentAnalyzer` 加进/移出
/// `pipelineController.setAnalyzers(...)`，用来验收 Stage 3 的两条验收项：检测框是否有
/// `GeometryUtils.QuadEMAFilter` 平滑（无可见抖动）、关闭后分析线程是否真的零 CPU 占用。
struct CameraDebugView: View {

    @StateObject private var viewModel = CameraDebugViewModel()

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                switch viewModel.previewMode {
                case .passthrough:
                    if let previewLayer = viewModel.previewLayer {
                        PassthroughPreviewContainer(previewLayer: previewLayer)
                    } else {
                        Color.black
                    }
                case .processed:
                    ProcessedPreviewContainer(renderedFrames: viewModel.renderedFrames)
                }
                // Histogram 曲线不受 previewMode 影响：CameraPipelineBridge 从 start() 起
                // 就在消费 cameraSource.frames，跟这里显示 Passthrough 还是 Processed 无关。
                OverlayCanvas(annotations: viewModel.screenAnnotations, showsGrid: false, showsLevel: false)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text("Session state: \(String(describing: viewModel.sessionState))")
                Text("Current lens: \(viewModel.currentLens.rawValue)")
                Text("Annotations received: \(viewModel.annotationCount)")
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Toggle(
                "Document detection",
                isOn: Binding(
                    get: { viewModel.detectionEnabled },
                    set: { enabled in Task { await viewModel.setDetectionEnabled(enabled) } }
                )
            )
            .padding(.horizontal)

            Button(viewModel.isCapturingDocument ? "Capturing…" : "Capture Document") {
                Task { await viewModel.captureDocument() }
            }
            .disabled(viewModel.isCapturingDocument)
            .padding(.horizontal)

            if let image = viewModel.capturedDocumentImage, let result = viewModel.lastDocumentCapture {
                VStack(alignment: .leading, spacing: 4) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                    Text("processed: \(result.processedFileURL.lastPathComponent)").font(.caption2)
                    Text("raw: \(result.rawFileURL?.lastPathComponent ?? "none")").font(.caption2)
                }
                .padding(.horizontal)
            }

            Picker("Preview", selection: $viewModel.previewMode) {
                Text("Passthrough").tag(PreviewMode.passthrough)
                Text("Processed").tag(PreviewMode.processed)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Picker(
                "Lens",
                selection: Binding(
                    get: { viewModel.currentLens },
                    set: { lens in Task { await viewModel.switchLens(lens) } }
                )
            ) {
                ForEach(LensType.allCases, id: \.self) { lens in
                    Text(lens.rawValue).tag(lens)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .task {
            await viewModel.start()
        }
    }
}

@MainActor
private final class CameraDebugViewModel: ObservableObject {

    private let session = CameraSession()
    private let sessionUseCase: CameraSessionUseCase
    private let pipelineController = PipelineController()
    private var bridge: CameraPipelineBridge?
    private var annotationObservationTask: Task<Void, Never>?
    private var overlayManager: OverlayManager?

    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var sessionState: SessionState = .idle
    @Published var currentLens: LensType = .wide
    @Published var previewMode: PreviewMode = .passthrough
    @Published var annotationCount: Int = 0
    @Published var screenAnnotations: [ScreenAnnotation] = []
    @Published var detectionEnabled: Bool = false
    @Published var isCapturingDocument = false
    @Published var lastDocumentCapture: PhotoCaptureResult?
    @Published var capturedDocumentImage: UIImage?

    // 分析链最近一次收到的 quad 检测结果，供 "Capture Document" 按钮复用——不重复跑一次 Vision 请求。
    private var latestQuad: Annotation?

    var renderedFrames: AsyncStream<MTLTexture> { pipelineController.renderedFrames }
    private lazy var documentCaptureUseCase = DocumentCaptureUseCase(cameraSource: session, pipeline: pipelineController)

    init() {
        sessionUseCase = CameraSessionUseCase(cameraSource: session)
    }

    func start() async {
        previewLayer = session.previewLayer
        await sessionUseCase.start()
        sessionState = await sessionUseCase.state

        let frameProvider = PreviewLayerFrameProvider(layerFrame: previewLayer?.frame ?? .zero)
        overlayManager = OverlayManager(converter: CoordinateConverter(previewLayer: frameProvider))

        await pipelineController.setAnalyzers([HistogramAnalyzer()])
        let bridge = CameraPipelineBridge(cameraSource: session, pipelineController: pipelineController)
        await bridge.start()
        self.bridge = bridge

        observeAnnotationsIfNeeded()
    }

    func switchLens(_ lens: LensType) async {
        try? await session.apply(.switchLens(lens))
        currentLens = lens
        sessionState = await sessionUseCase.state
    }

    func setDetectionEnabled(_ enabled: Bool) async {
        detectionEnabled = enabled
        let analyzers: [any FrameAnalyzer] = enabled ? [HistogramAnalyzer(), DocumentAnalyzer()] : [HistogramAnalyzer()]
        await pipelineController.setAnalyzers(analyzers)
    }

    // targetSize 800x1100 只是调试用的固定占位比例（约等于 A4 竖版的近似比例，不追求精确），
    // 真正的目标尺寸应该在正式相机页面里由用户/预设决定（见 stage4_camera_plugin_preset_plan.md）。
    func captureDocument() async {
        isCapturingDocument = true
        defer { isCapturingDocument = false }
        do {
            let result = try await documentCaptureUseCase.capture(
                latestQuad: latestQuad, targetSize: CGSize(width: 800, height: 1100)
            )
            lastDocumentCapture = result
            capturedDocumentImage = UIImage(contentsOfFile: result.processedFileURL.path)
        } catch {
            print("CameraDebugView: captureDocument failed: \(error)")
        }
    }

    private func observeAnnotationsIfNeeded() {
        guard annotationObservationTask == nil else { return }
        let pipelineController = pipelineController
        annotationObservationTask = Task { [weak self] in
            for await batch in pipelineController.annotations {
                guard let self else { return }
                self.annotationCount = batch.annotations.count
                if let quad = batch.annotations.first(where: {
                    if case .quad = $0 { return true } else { return false }
                }) {
                    self.latestQuad = quad
                }
                // 每批都用当前 previewLayer.frame 现造一个新 provider——布局尺寸会随旋转/生命周期变化，
                // 缓存旧值会导致检测框逐渐跟预览画面对不上（也修掉了 start() 里早期 .zero 快照的问题）。
                if let overlayManager = self.overlayManager {
                    overlayManager.converter = CoordinateConverter(
                        previewLayer: PreviewLayerFrameProvider(layerFrame: self.previewLayer?.frame ?? .zero)
                    )
                    self.screenAnnotations = overlayManager.makeScreenAnnotations(
                        from: batch.annotations, uprightImageSize: batch.uprightImageSize
                    )
                }
            }
        }
    }
}

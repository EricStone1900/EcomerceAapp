import AVFoundation
import CoreMedia
@preconcurrency import Metal
import Testing

import CameraCore
import CameraPipeline
import Shared
@testable import CameraFeature

private actor RecordingCameraSource: CameraSourceProtocol {

    private(set) var appliedControls: [CameraControl] = []

    nonisolated let frames: AsyncStream<CameraCore.Frame> = AsyncStream { _ in }
    nonisolated let capability: AsyncStream<DeviceCapability> = AsyncStream { _ in }
    nonisolated let interruptions: AsyncStream<InterruptionEvent> = AsyncStream { _ in }
    nonisolated(unsafe) let previewLayer = AVCaptureVideoPreviewLayer()

    func apply(_ control: CameraControl) async throws {
        appliedControls.append(control)
    }

    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult {
        throw CameraError.captureFailed(underlying: nil)
    }

    func currentExposureMetadata() -> CaptureExposureMetadata {
        CaptureExposureMetadata(iso: 0, shutterDuration: .zero, lensPosition: 0)
    }
}

private struct StubProcessor: FrameProcessor {
    let id: PluginID
    func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture { texture }
}

private struct StubAnalyzer: FrameAnalyzer {
    let id: PluginID
    let preferredFPS = 10
    func analyze(_ frame: CameraPipeline.Frame) async -> [Annotation] { [] }
}

private func makeCapability(isoRange: ClosedRange<Float> = 50...800) -> DeviceCapability {
    DeviceCapability(
        lens: .wide,
        isoRange: isoRange,
        shutterRange: CMTime(value: 1, timescale: 8000)...CMTime(value: 1, timescale: 4),
        evRange: -2...2,
        wbGainsRange: WBGainsRange(redRange: 1...4, greenRange: 1...4, blueRange: 1...4),
        supportsRAW: true,
        supportsProRAW: false,
        maxZoomFactor: 2,
        supportedFormats: []
    )
}

@Suite("PresetUseCase.apply")
struct PresetUseCaseTests {

    @Test("resolves and installs the preset's processors and analyzers into the pipeline")
    func installsResolvedPlugins() async throws {
        let source = RecordingCameraSource()
        let pipeline = PipelineController()
        let registry = PluginRegistry()
        registry.register(StubProcessor(id: PluginID("lut.food")), id: PluginID("lut.food"))
        registry.register(StubAnalyzer(id: PluginID("face")), id: PluginID("face"))
        let useCase = PresetUseCase(cameraSource: source, pipeline: pipeline, registry: registry)
        let preset = CameraPreset(
            name: "Test", lens: .wide, manual: nil,
            processorIDs: ["lut.food"], analyzerIDs: ["face"], captureFormat: .heif
        )

        let result = await useCase.apply(preset, capability: makeCapability())

        #expect(result.processorCount == 1)
    }

    @Test("clamps out-of-range manual settings before applying camera controls")
    func clampsBeforeApplyingControls() async {
        let source = RecordingCameraSource()
        let pipeline = PipelineController()
        let registry = PluginRegistry()
        let useCase = PresetUseCase(cameraSource: source, pipeline: pipeline, registry: registry)
        let preset = CameraPreset(
            name: "Night", lens: .wide, manual: ManualSettings(iso: 3200),
            processorIDs: [], analyzerIDs: [], captureFormat: .heif
        )

        let result = await useCase.apply(preset, capability: makeCapability(isoRange: 50...800))

        #expect(result.clamped.manual?.iso == 800)
        let applied = await source.appliedControls
        guard case .setISO(let appliedISO)? = applied.first else {
            Issue.record("expected a .setISO control to have been applied")
            return
        }
        #expect(appliedISO == 800) // 传给相机的是 clamp 后的值，不是 preset 原始的 3200
    }

    @Test("a preset that resolves to zero processors reports processorCount 0")
    func reportsZeroProcessorsForPurelyAnalyticalPreset() async {
        let source = RecordingCameraSource()
        let pipeline = PipelineController()
        let registry = PluginRegistry()
        let useCase = PresetUseCase(cameraSource: source, pipeline: pipeline, registry: registry)

        let result = await useCase.apply(.document, capability: makeCapability())

        #expect(result.processorCount == 0)
    }
}

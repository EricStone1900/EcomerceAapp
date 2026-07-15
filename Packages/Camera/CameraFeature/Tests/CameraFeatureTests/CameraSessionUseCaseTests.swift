import AVFoundation
import CoreGraphics
import CoreMedia
import Testing

import CameraCore
import Shared
@testable import CameraFeature

private actor MockCameraSource: CameraSourceProtocol, CaptureSessionProviding {

    var shouldFailStart = false
    private(set) var startRunningCallCount = 0

    nonisolated let frames: AsyncStream<Frame> = AsyncStream { _ in }
    nonisolated let capability: AsyncStream<DeviceCapability> = AsyncStream { _ in }
    nonisolated let interruptions: AsyncStream<InterruptionEvent>
    nonisolated(unsafe) let previewLayer = AVCaptureVideoPreviewLayer()

    private let interruptionContinuation: AsyncStream<InterruptionEvent>.Continuation

    init() {
        var continuation: AsyncStream<InterruptionEvent>.Continuation!
        interruptions = AsyncStream { continuation = $0 }
        interruptionContinuation = continuation
    }

    func startRunning() async throws {
        startRunningCallCount += 1
        if shouldFailStart {
            throw CameraError.sessionConfigurationFailed(underlying: nil)
        }
    }

    func stopRunning() async {}

    func configureOutputs() async throws {}

    func apply(_ control: CameraControl) async throws {}

    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult {
        throw CameraError.captureFailed(underlying: nil)
    }

    func setShouldFailStart(_ value: Bool) {
        shouldFailStart = value
    }

    func simulateInterruption(_ event: InterruptionEvent) {
        interruptionContinuation.yield(event)
    }

    func currentExposureMetadata() -> CaptureExposureMetadata {
        CaptureExposureMetadata(iso: 0, shutterDuration: .zero, lensPosition: 0)
    }
}

@Suite("CameraSessionUseCase")
struct CameraSessionUseCaseTests {

    @Test("start() transitions to running when the source starts successfully")
    func startSucceeds() async {
        let source = MockCameraSource()
        let useCase = CameraSessionUseCase(cameraSource: source)

        await useCase.start()
        let state = await useCase.state

        #expect(state == .running)
    }

    @Test("start() transitions to interrupted when the source throws")
    func startFailurePropagatesAsInterrupted() async {
        let source = MockCameraSource()
        await source.setShouldFailStart(true)
        let useCase = CameraSessionUseCase(cameraSource: source)

        await useCase.start()
        let state = await useCase.state

        guard case .interrupted = state else {
            Issue.record("expected .interrupted state, got \(state)")
            return
        }
    }

    @Test("handleInterruption(ended: true) drives the state machine back to running")
    func interruptionEndedRecoversSession() async {
        let source = MockCameraSource()
        let useCase = CameraSessionUseCase(cameraSource: source)

        await useCase.handleInterruption(ended: false, reason: "phone call")
        let interruptedState = await useCase.state
        #expect(interruptedState == .interrupted(reason: "phone call"))

        await useCase.handleInterruption(ended: true, reason: "phone call")
        let recoveredState = await useCase.state
        #expect(recoveredState == .running)
    }

    @Test("real interruption events from the source's stream drive the state machine automatically")
    func interruptionStreamDrivesStateAutomatically() async throws {
        let source = MockCameraSource()
        let useCase = CameraSessionUseCase(cameraSource: source)

        await useCase.start()
        #expect(await useCase.state == .running)

        await source.simulateInterruption(.began(reason: "phone call"))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await useCase.state == .interrupted(reason: "phone call"))

        await source.simulateInterruption(.ended)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await useCase.state == .running)

        // .ended 触发的自动恢复会重新调用 startRunning()：一次 start() 手动调用 + 一次自动恢复。
        let callCount = await source.startRunningCallCount
        #expect(callCount == 2)
    }
}

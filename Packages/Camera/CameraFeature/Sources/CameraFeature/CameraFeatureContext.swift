import Foundation

import CameraCore
import CameraPipeline

/// 装配好的相机功能依赖集合——App 组合根（`AppCameraComposition.makeCameraFeature()`）负责
/// 构造并往 `registry` 里注册具体插件（`CameraVision`/`CameraML`/`CameraFilters` 的类型），
/// 这个结构体本身只是"契约"：不知道也不需要知道任何具体插件类型的存在，只依赖
/// `CameraFeature`/`CameraCore`/`CameraPipeline`。这样 `CameraUI.CameraViewModel` 才能
/// `import CameraFeature` 拿到这个类型，而不需要反过来依赖 `CameraVision`/`CameraML`/
/// `CameraFilters`（那会破坏"UI 不感知插件细节"这条设计目标）。
public struct CameraFeatureContext: Sendable {
    public let session: CameraSession
    public let pipeline: PipelineController
    public let registry: PluginRegistry
    public let presetUseCase: PresetUseCase
    public let thermalPolicyUseCase: ThermalPolicyUseCase
    public let documentCaptureUseCase: DocumentCaptureUseCase
    public let thermalObserver: ThermalObserver

    public init(
        session: CameraSession,
        pipeline: PipelineController,
        registry: PluginRegistry,
        presetUseCase: PresetUseCase,
        thermalPolicyUseCase: ThermalPolicyUseCase,
        documentCaptureUseCase: DocumentCaptureUseCase,
        thermalObserver: ThermalObserver
    ) {
        self.session = session
        self.pipeline = pipeline
        self.registry = registry
        self.presetUseCase = presetUseCase
        self.thermalPolicyUseCase = thermalPolicyUseCase
        self.documentCaptureUseCase = documentCaptureUseCase
        self.thermalObserver = thermalObserver
    }
}

/// 订阅系统真实的 `ProcessInfo.thermalStateDidChangeNotification`，自动驱动
/// `ThermalPolicyUseCase.handle`——Stage 4 验收清单里"thermal critical 时自动回落 passthrough"
/// 这条"自动"二字的字面落地：不需要任何人手动调用，设备真的发热了就会自己触发降级。
/// `shouldForcePassthrough` 是给 UI 层订阅的信号流，`CameraViewModel` 用它切换
/// `CameraViewState.previewMode`。
/// `@unchecked Sendable`：`observer` 已经标了 `nonisolated(unsafe)`（deinit 需要在非隔离上下文里
/// 摸到它），整个类型实际上只会在 MainActor 上下文里构造/使用，标出来是为了让持有它的
/// `CameraFeatureContext` 能满足 `Sendable`（构造好之后要从 App 组合根传给 CameraUI 的
/// ViewModel），不是真的允许任意线程并发访问。
@MainActor
public final class ThermalObserver: @unchecked Sendable {

    private let thermalPolicyUseCase: ThermalPolicyUseCase
    nonisolated(unsafe) private var observer: NSObjectProtocol?
    private let continuation: AsyncStream<Bool>.Continuation
    public let shouldForcePassthrough: AsyncStream<Bool>

    public init(thermalPolicyUseCase: ThermalPolicyUseCase) {
        self.thermalPolicyUseCase = thermalPolicyUseCase
        var continuation: AsyncStream<Bool>.Continuation!
        shouldForcePassthrough = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let state = ThermalState(systemThermalState: ProcessInfo.processInfo.thermalState)
                let forcePassthrough = await self.thermalPolicyUseCase.handle(state)
                self.continuation.yield(forcePassthrough)
            }
        }
    }

    public func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    nonisolated deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

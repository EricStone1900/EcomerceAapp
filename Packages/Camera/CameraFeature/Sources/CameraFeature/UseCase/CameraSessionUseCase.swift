import CameraCore
import Shared

public enum SessionPermissionState: Sendable, Equatable {
    case notDetermined, authorized, denied, restricted
}

public enum SessionState: Sendable, Equatable {
    case idle, requestingPermission, permissionDenied, starting, running, interrupted(reason: String)
}

/// 启动/权限/中断恢复状态机。CameraSession（Core）只产出事件，
/// 状态机编排（例如权限被拒后引导用户去设置、返回 App 后自动重试）属于本用例。
///
/// 依赖 `CameraSourceProtocol & CaptureSessionProviding` 而不是单独一个协议：前者暴露
/// frames/capability/apply/capturePhoto，后者暴露 startRunning/stopRunning/configureOutputs——
/// 真正的会话生命周期只在 CaptureSessionProviding 里，本用例的名字就叫 CameraSessionUseCase，
/// 没有它就没法真的"启动"会话。两个协议故意没有合并，因为 Stage 1 的 FramePlaybackProvider
/// 只需要实现 CaptureSessionProviding（用于驱动 Pipeline/Vision/ML 单测，不需要真实采集）。
public actor CameraSessionUseCase {

    private let cameraSource: any CameraSourceProtocol & CaptureSessionProviding
    public private(set) var state: SessionState = .idle
    private var interruptionObservationTask: Task<Void, Never>?

    public init(cameraSource: any CameraSourceProtocol & CaptureSessionProviding) {
        self.cameraSource = cameraSource
    }

    deinit {
        interruptionObservationTask?.cancel()
    }

    public func start() async {
        observeInterruptionsIfNeeded()

        state = .requestingPermission
        state = .starting
        do {
            try await cameraSource.startRunning()
            state = .running
        } catch CameraError.permissionDenied {
            state = .permissionDenied
        } catch {
            state = .interrupted(reason: "\(error)")
        }
    }

    /// 订阅 CameraSession 的中断事件流，自动驱动状态机——不需要调用方手动转发通知。
    /// 放在 start() 里第一次调用时才订阅（而不是 init 里）：actor 的 init 阶段 self 还没有
    /// 完成"进入隔离域"，这里创建的 Task 弱引用 self 会触发 Swift 6 的
    /// "cannot access property here in nonisolated initializer" 报错。
    ///
    /// 通过 `any CameraSourceProtocol` 存在类型访问 interruptions 时，即使具体类型
    /// （CameraSession）把它实现成 nonisolated，协议本身声明的隔离级别仍然要求 await。
    private func observeInterruptionsIfNeeded() {
        guard interruptionObservationTask == nil else { return }
        let cameraSource = cameraSource
        interruptionObservationTask = Task { [weak self] in
            let stream = await cameraSource.interruptions
            for await event in stream {
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: InterruptionEvent) async {
        switch event {
        case .began(let reason):
            state = .interrupted(reason: reason)
        case .runtimeError(let reason):
            state = .interrupted(reason: reason)
        case .ended:
            // 手动参数（ISO/快门/EV/WB）由调用方在 .running 之后按需重放，
            // 保证锁屏-解锁后参数保持（Stage 1 验收项之一）——CameraSession 本身
            // 不记忆上一次的手动设置，重放逻辑属于更上层（UI/Preset）的职责。
            await start()
        }
    }

    /// 保留手动触发入口，供测试或需要精确控制时机的调用方使用；正常运行时
    /// init 里订阅的 interruptions 流已经会自动调用到与本方法等价的逻辑。
    public func handleInterruption(ended: Bool, reason: String) async {
        if ended {
            await start()
        } else {
            state = .interrupted(reason: reason)
        }
    }
}

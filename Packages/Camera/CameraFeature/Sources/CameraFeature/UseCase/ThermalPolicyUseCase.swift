import Foundation

import CameraPipeline

public enum ThermalState: Sendable, Equatable {
    case nominal, fair, serious, critical
}

extension ThermalState {
    /// 把系统的 `ProcessInfo.ThermalState` 映射成本模块自己的 `ThermalState`——`handle(_:)` 的
    /// 签名不直接依赖 `Foundation.ProcessInfo` 这种系统 API 细节，方便测试时构造任意状态，
    /// 不需要真的触发系统热事件（那在单元测试里几乎不可能可靠复现）。App 层订阅
    /// `ProcessInfo.thermalStateDidChangeNotification` 时用这个初始化器转换。
    public init(systemThermalState: ProcessInfo.ThermalState) {
        switch systemThermalState {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .fair
        }
    }
}

/// 热降级策略：`.serious` 给分析链降频（不清空 analyzer，只是跑得没那么勤），
/// `.critical` 直接停掉整条分析链（`setAnalyzers([])`）。
///
/// 显式声明 `Sendable`（存储属性只有 actor `PipelineController` 和 `Int`，本身安全）——
/// Swift 对 public 类型的隐式 Sendable 推导不保证跨模块可靠传播，从另一个 target
/// （比如 App 层的 `ThermalObserver`）把这个值送进跨 actor 边界的调用时，编译器需要看到
/// 明确写出来的 `Sendable` conformance，否则会报"sending non-Sendable value risks data races"。
public struct ThermalPolicyUseCase: Sendable {

    private let pipeline: PipelineController

    /// 分析链每隔多少帧才真正跑一次（`.serious` 时生效），默认 3——1/3 帧率，
    /// 在"还能看到检测结果"和"明显降低计算量"之间取的一个折中值，不是精确调过的最优参数。
    private let seriousStateDivisor: Int

    public init(pipeline: PipelineController, seriousStateDivisor: Int = 3) {
        self.pipeline = pipeline
        self.seriousStateDivisor = seriousStateDivisor
    }

    /// 返回 true 表示调用方应该强制把预览切回 passthrough（只有 `.critical` 会这样）。
    /// 不直接依赖 `CameraUI.PreviewMode`——`CameraFeature` 不应该反向依赖 UI 层的具体类型，
    /// 由调用方自己决定"回落 passthrough"具体怎么落到 UI 状态上。
    @discardableResult
    public func handle(_ state: ThermalState) async -> Bool {
        switch state {
        case .serious:
            await pipeline.setAnalysisRateDivisor(seriousStateDivisor)
            return false
        case .critical:
            await pipeline.setAnalyzers([])
            await pipeline.setAnalysisRateDivisor(1)
            return true
        case .nominal, .fair:
            await pipeline.setAnalysisRateDivisor(1)
            return false
        }
    }
}

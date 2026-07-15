// Metal 的协议类型（MTLTexture 等）还没有被 Apple 标注 Sendable，@preconcurrency 让编译器
// 把跨 actor 边界传递这些类型当作"未审计、由调用方负责"处理，而不是当成硬错误拦下来。
@preconcurrency import Metal

public actor PipelineController {

    private var processors: [any FrameProcessor] = []
    private var analyzers: [any FrameAnalyzer] = []
    private var inFlightAnalysisTask: Task<Void, Never>?
    // 热降级（ThermalPolicyUseCase 的 .serious 分支）用：每 analysisRateDivisor 帧只让 1 帧真的
    // 跑分析链，其余直接跳过——不清空 analyzers（那是 .critical 才做的更激进的降级），只是降频。
    private var analysisRateDivisor = 1
    private var frameCounter = 0

    // 两个 continuation 都是私有的，只在本 actor 内部（consume 及其派生的 Task）使用，
    // 保持普通 actor-isolated 存储即可，不需要 nonisolated。
    private let annotationContinuation: AsyncStream<AnnotationBatch>.Continuation
    private let renderedFrameContinuation: AsyncStream<MTLTexture>.Continuation

    public nonisolated let annotations: AsyncStream<AnnotationBatch>
    // renderedFrames 对外暴露给 CameraUI.ProcessedPreviewContainer（非 async 的
    // UIViewRepresentable.makeUIView 里消费），MTLTexture 不是 Sendable，用 nonisolated(unsafe)
    // 声明为可安全跨隔离域读取（原因同 CameraCore.CameraSession.previewLayer：init 赋值一次后不再变）。
    public nonisolated(unsafe) let renderedFrames: AsyncStream<MTLTexture>

    public init() {
        var annotationContinuation: AsyncStream<AnnotationBatch>.Continuation!
        annotations = AsyncStream { annotationContinuation = $0 }
        var renderedFrameContinuation: AsyncStream<MTLTexture>.Continuation!
        renderedFrames = AsyncStream { renderedFrameContinuation = $0 }

        self.annotationContinuation = annotationContinuation
        self.renderedFrameContinuation = renderedFrameContinuation
    }

    public func setProcessors(_ ps: [any FrameProcessor]) {
        processors = ps
    }

    public func setAnalyzers(_ newAnalyzers: [any FrameAnalyzer]) {
        analyzers = newAnalyzers
    }

    /// divisor <= 1 等于不降频（每帧都跑）。设置新 divisor 会重置 frameCounter，避免刚调低倍率
    /// 时因为沿用旧计数导致第一帧被意外跳过或意外触发。
    public func setAnalysisRateDivisor(_ divisor: Int) {
        analysisRateDivisor = max(1, divisor)
        frameCounter = 0
    }

    /// CameraCore.frames 的消费入口：渲染链同步跑完立刻产出 renderedFrames；
    /// 分析链按 latest-frame-wins 丢帧调度——新帧到达时若上一轮分析未完成，取消旧任务而不是排队。
    public func consume(_ frame: Frame, texture: MTLTexture, context: RenderContext) {
        var output = texture
        for processor in processors {
            output = processor.process(output, context: context)
        }
        renderedFrameContinuation.yield(output)

        guard !analyzers.isEmpty else { return }

        frameCounter += 1
        guard frameCounter % analysisRateDivisor == 0 else { return }

        inFlightAnalysisTask?.cancel()
        let analyzers = self.analyzers
        let uprightImageSize = frame.uprightImageSize
        inFlightAnalysisTask = Task {
            var collected: [Annotation] = []
            for analyzer in analyzers {
                if Task.isCancelled { return }
                collected.append(contentsOf: await analyzer.analyze(frame))
            }
            if !Task.isCancelled {
                self.annotationContinuation.yield(AnnotationBatch(annotations: collected, uprightImageSize: uprightImageSize))
            }
        }
    }
}

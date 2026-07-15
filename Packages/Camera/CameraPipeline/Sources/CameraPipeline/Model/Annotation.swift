import CoreGraphics
import Foundation

public struct HistogramData: Sendable {
    public let redBuckets: [Float]
    public let greenBuckets: [Float]
    public let blueBuckets: [Float]
    public let luminanceBuckets: [Float]

    public init(redBuckets: [Float], greenBuckets: [Float], blueBuckets: [Float], luminanceBuckets: [Float]) {
        self.redBuckets = redBuckets
        self.greenBuckets = greenBuckets
        self.blueBuckets = blueBuckets
        self.luminanceBuckets = luminanceBuckets
    }
}

public struct DetectedObject: Sendable {
    public let label: String
    public let boundingBox: CGRect
    public let confidence: Float

    public init(label: String, boundingBox: CGRect, confidence: Float) {
        self.label = label
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

/// 分析结果的统一模型。统一携带归一化坐标，转换到屏幕坐标是 OverlayManager 的事
/// （用 Shared.CoordinateConverter）。quad 类结果在 OverlayManager 内做 EMA 时域平滑，消除抖动。
public enum Annotation: Sendable {
    case quad(id: UUID, corners: [CGPoint], confidence: Float)  // 文档/卡片，Stage 3 接入
    case histogram(HistogramData)
    case objects([DetectedObject])
    case horizon(angle: Double)
    case custom(key: String, payload: any Sendable)             // V5 扩展口
}

/// PipelineController.annotations 流的载荷：annotations 本身是归一化坐标，脱离产出它们的那一帧
/// 就无法正确转换成屏幕坐标（aspect-fill 裁切偏移依赖图像宽高比），所以把两者绑在一起传出去，
/// 而不是只传 [Annotation] 让消费方自己猜图像尺寸。
public struct AnnotationBatch: Sendable {
    public let annotations: [Annotation]
    public let uprightImageSize: CGSize

    public init(annotations: [Annotation], uprightImageSize: CGSize) {
        self.annotations = annotations
        self.uprightImageSize = uprightImageSize
    }
}

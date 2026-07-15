import CoreGraphics

import CameraPipeline

/// Annotation 转换到屏幕坐标后的展示模型（用 Shared.CoordinateConverter 转换）。
public enum ScreenAnnotation: Sendable {
    case quad(corners: [CGPoint])
    case histogram(HistogramData)
    case objects([CGRect])
    case horizon(angle: Double)
}

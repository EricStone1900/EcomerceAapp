import CoreGraphics

import CameraPipeline
import Shared

/// 把 [Annotation] 转成 [ScreenAnnotation]：用 Shared.CoordinateConverter 转换坐标，
/// quad 类型额外过一遍 GeometryUtils.QuadEMAFilter 做时域平滑。
public final class OverlayManager {

    private var quadFilter = GeometryUtils.QuadEMAFilter()
    // previewLayer 的实际 frame 只有在真实布局发生后才有意义（构造时机往往早于布局），
    // 调用方应该在每批 annotations 到达时用当前 previewLayer.frame 刷新这个属性，而不是
    // 只在 init 时传一次快照——否则坐标转换会一直用一个陈旧（很可能是 .zero）的 frame。
    public var converter: CoordinateConverter

    public init(converter: CoordinateConverter) {
        self.converter = converter
    }

    /// uprightImageSize 来自产出这批 annotations 的那一帧（见 CameraPipeline.AnnotationBatch），
    /// 用来算 aspect-fill 裁切偏移，不传的话退化成 Stage 1 的纯缩放（quad 会偏移/压扁）。
    public func makeScreenAnnotations(from annotations: [Annotation], uprightImageSize: CGSize) -> [ScreenAnnotation] {
        annotations.map { annotation in
            switch annotation {
            case .quad(_, let corners, _):
                let screenCorners = corners.map { converter.convert(normalizedPoint: $0, uprightImageSize: uprightImageSize) }
                let smoothed = quadFilter.update(screenCorners)
                return .quad(corners: smoothed)
            case .histogram(let data):
                return .histogram(data)
            case .horizon(let angle):
                return .horizon(angle: angle)
            case .objects(let objects):
                return .objects(objects.map { $0.boundingBox })
            case .custom:
                return .quad(corners: []) // V5 custom 类型的绘制留给具体插件扩展 OverlayCanvas
            }
        }
    }
}

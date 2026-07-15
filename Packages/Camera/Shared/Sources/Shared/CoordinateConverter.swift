import CoreGraphics

/// 抽象出 previewLayer.frame，避免 Shared 直接依赖 UIKit/AVFoundation 具体类型，便于单测。
public protocol CALayerFrameProviding: Sendable {
    var layerFrame: CGRect { get }
}

/// 统一把 Vision 归一化坐标(左下原点)转换为预览层 UIKit 坐标。
/// 封装 rotation / mirror / videoGravity 裁切偏移，所有 Overlay 只允许用这一个服务转换。
public struct CoordinateConverter: Sendable {
    public let previewLayer: any CALayerFrameProviding

    public init(previewLayer: any CALayerFrameProviding) {
        self.previewLayer = previewLayer
    }

    /// 输入 Vision 归一化坐标（左下原点，0...1）+ 摆正后的图像尺寸（已按 frame.orientation 转正，
    /// 只用到宽高比），输出预览层坐标系下的点。
    ///
    /// 假设预览层 videoGravity 是 `.resizeAspectFill`（PassthroughPreviewContainer 里设置的值）：
    /// 图像等比放大到完全铺满 layer，溢出的部分两侧对称裁掉。归一化坐标是相对整张图像的，
    /// 不乘上被裁掉的溢出量、不加回居中偏移的话，检测框会系统性偏移/压扁。
    /// 转换出的点允许落在 layer bounds 之外（对应图像上被裁掉的区域），由绘制方自行裁剪。
    public func convert(normalizedPoint point: CGPoint, uprightImageSize: CGSize) -> CGPoint {
        let flipped = CGPoint(x: point.x, y: 1 - point.y)
        let bounds = previewLayer.layerFrame
        guard uprightImageSize.width > 0, uprightImageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else {
            // 尺寸未知时退化为纯缩放（Stage 1 的原始行为），至少保证不崩、不返回 NaN。
            return CGPoint(x: flipped.x * bounds.width, y: flipped.y * bounds.height)
        }
        let scale = max(bounds.width / uprightImageSize.width, bounds.height / uprightImageSize.height)
        let displayedSize = CGSize(
            width: uprightImageSize.width * scale,
            height: uprightImageSize.height * scale
        )
        let offset = CGPoint(
            x: (bounds.width - displayedSize.width) / 2,
            y: (bounds.height - displayedSize.height) / 2
        )
        return CGPoint(
            x: flipped.x * displayedSize.width + offset.x,
            y: flipped.y * displayedSize.height + offset.y
        )
    }

    /// 图像尺寸未知时的兼容入口：纯"翻转 y + 按 layer 缩放"，不含 aspect-fill 裁切偏移。
    public func convert(normalizedPoint point: CGPoint) -> CGPoint {
        convert(normalizedPoint: point, uprightImageSize: .zero)
    }
}

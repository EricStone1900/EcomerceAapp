import CoreImage
@preconcurrency import Metal

import CameraPipeline

/// 简化版磨皮：高斯模糊 + 按固定透明度叠加回原图（`CISourceOverCompositing`）。
///
/// 不是商业美颜 App 那种基于人脸关键点网格的精细磨皮（那需要 Vision 人脸网格 + 更复杂的双边/
/// 表面模糊算法，超出本 stage"验证插件生态可扩展"这个目标范围），但是一个真实、能跑、能测的
/// 整体柔化效果，不是占位实现——`blurRadius`/`blendAlpha` 都是可调参数，效果强弱可控。
public struct BeautyProcessor: FrameProcessor, @unchecked Sendable {

    public let id: PluginID
    private let ciContext: CIContext
    private let blurRadius: Double
    private let blendAlpha: CGFloat

    public init(id: PluginID = PluginID("beauty"), ciContext: CIContext, blurRadius: Double = 4, blendAlpha: CGFloat = 0.5) {
        self.id = id
        self.ciContext = ciContext
        self.blurRadius = blurRadius
        self.blendAlpha = blendAlpha
    }

    public func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture {
        renderProcessedTexture(from: texture, context: context, ciContext: ciContext) { image in
            // CIGaussianBlur 会向外扩张 extent（取样半径的副作用），先 clampedToExtent 避免边缘取到
            // 透明像素，再裁回原始 extent。
            guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return image }
            blurFilter.setValue(image.clampedToExtent(), forKey: kCIInputImageKey)
            blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
            guard let blurred = blurFilter.outputImage?.cropped(to: image.extent) else { return image }

            // CIColorMatrix 把模糊结果的 alpha 通道整体缩到 blendAlpha，实现"半透明叠加"而不是
            // 完全替换——这样原图的细节还在，只是被模糊版本柔化了一部分。
            guard let alphaFilter = CIFilter(name: "CIColorMatrix") else { return image }
            alphaFilter.setValue(blurred, forKey: kCIInputImageKey)
            alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: blendAlpha), forKey: "inputAVector")
            guard let translucentBlur = alphaFilter.outputImage else { return image }

            guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else { return image }
            compositeFilter.setValue(translucentBlur, forKey: kCIInputImageKey)
            compositeFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
            return compositeFilter.outputImage
        }
    }
}

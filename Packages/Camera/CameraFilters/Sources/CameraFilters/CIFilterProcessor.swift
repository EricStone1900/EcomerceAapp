import CoreImage
@preconcurrency import Metal

import CameraPipeline

/// 通用 CIFilter 包装：把任意一个 CIFilter 接进渲染链，texture -> CIImage -> filter -> 渲染回一个新
/// MTLTexture（见 `renderProcessedTexture`）。
///
/// `CIFilter` 不是 Sendable（Apple 没标注），处理方式跟 CameraPipeline.Frame/RenderContext 对
/// Metal/CoreImage 类型的处理一致：标 `@unchecked Sendable`——`PipelineController.consume` 把所有
/// processor 串行跑在 actor 隔离域内，不存在并发修改 filter 的场景。
public struct CIFilterProcessor: FrameProcessor, @unchecked Sendable {

    public let id: PluginID
    private let filter: CIFilter
    private let ciContext: CIContext

    public init(id: PluginID, filter: CIFilter, ciContext: CIContext) {
        self.id = id
        self.filter = filter
        self.ciContext = ciContext
    }

    public func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture {
        renderProcessedTexture(from: texture, context: context, ciContext: ciContext) { image in
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage
        }
    }
}

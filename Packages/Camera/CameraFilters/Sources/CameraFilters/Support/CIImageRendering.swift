import CoreGraphics
import CoreImage
@preconcurrency import Metal

import CameraPipeline

/// `CIFilterProcessor` / `LUTProcessor` / `BeautyProcessor` 共用的渲染尾段：
/// `MTLTexture -> CIImage -> transform -> 渲染回一个跟源纹理同尺寸/同像素格式的新 MTLTexture`。
/// 全程走 `CIContext(mtlDevice:)` 的 GPU 路径（跟 `CameraUI.ProcessedPreviewContainer` 的设计一致），
/// 不经过 CPU 侧的 CIImage↔UIImage 往返（"内存铁律"，见 CameraPipeline.Frame 顶部注释）。
/// `transform` 失败（滤镜输出 nil 等）时退回原始 texture，不让一次滤镜失败中断整条渲染链——
/// `FrameProcessor.process(_:context:)` 本身不是 throwing 接口，调用方（PipelineController.consume）
/// 也没有处理单个 processor 失败的机制。
func renderProcessedTexture(
    from sourceTexture: MTLTexture,
    context: RenderContext,
    ciContext: CIContext,
    transform: (CIImage) -> CIImage?
) -> MTLTexture {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
        let sourceImage = CIImage(mtlTexture: sourceTexture, options: [.colorSpace: colorSpace]),
        let outputImage = transform(sourceImage),
        !outputImage.extent.isEmpty,
        let outputTexture = makeCompatibleTexture(like: sourceTexture, device: context.device)
    else {
        return sourceTexture
    }

    let targetExtent = CGRect(x: 0, y: 0, width: sourceTexture.width, height: sourceTexture.height)
    let scaled = outputImage.transformed(by: CGAffineTransform(
        scaleX: targetExtent.width / outputImage.extent.width,
        y: targetExtent.height / outputImage.extent.height
    ))

    ciContext.render(scaled, to: outputTexture, commandBuffer: context.commandBuffer, bounds: targetExtent, colorSpace: colorSpace)
    return outputTexture
}

private func makeCompatibleTexture(like source: MTLTexture, device: MTLDevice) -> MTLTexture? {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: source.pixelFormat, width: source.width, height: source.height, mipmapped: false
    )
    // .shaderWrite 是 CIContext.render(_:to:...) 真正写入目标纹理所必需的——只给 .renderTarget
    // 不够：在这台机器上实测会静默不写任何数据（纹理保持初始值，不报错也不崩溃），
    // 见 CameraFilters 这轮开发时的探测脚本（renderProcessedTexture 单测最初全部失败就是这个坑）。
    descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
    return device.makeTexture(descriptor: descriptor)
}

// Metal 协议类型（MTLTexture）未标注 Sendable，见 CameraPipeline.PipelineController 顶部注释。
@preconcurrency import Metal
import CoreGraphics
import CoreImage
import MetalKit
import SwiftUI

import CameraPipeline

/// 消费 PipelineController.renderedFrames，与 Passthrough 二选一显示。
///
/// 渲染实现选了 CIContext（而不是手写 MSL vertex/fragment shader 直接画三角形）：GPU 侧直接
/// MTLTexture → CIImage → 写回 drawable.texture，不经过 CPU（不是"内存铁律"里禁止的那种
/// CIImage↔UIImage 往返，那条规则针对的是分析链对 CVPixelBuffer/CMSampleBuffer 的处理，不是
/// 最终把已经转换好的纹理画到屏幕这一步），换来的是不用在 SPM target 里管理 .metal shader
/// 编译/`makeDefaultLibrary(bundle:)` 这条本包完全没法用 CLI 验证的路径上更小的出错面。
public struct ProcessedPreviewContainer: UIViewRepresentable {

    let renderedFrames: AsyncStream<MTLTexture>

    public init(renderedFrames: AsyncStream<MTLTexture>) {
        self.renderedFrames = renderedFrames
    }

    public func makeUIView(context: Context) -> MTKView {
        let device = MTLCreateSystemDefaultDevice()
        let view = MTKView(frame: .zero, device: device)
        // 不用 MTKView 自带的定时 draw() 回调——由 renderedFrames 到达时手动驱动一次渲染。
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        // CIContext.render(_:to:...) 需要直接写 drawable 的 texture，framebufferOnly 必须关掉。
        view.framebufferOnly = false
        context.coordinator.attach(view: view, stream: renderedFrames)
        return view
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    public final class Coordinator {
        private var consumeTask: Task<Void, Never>?
        private var commandQueue: MTLCommandQueue?
        private var ciContext: CIContext?

        func attach(view: MTKView, stream: consuming AsyncStream<MTLTexture>) {
            consumeTask?.cancel()
            guard let device = view.device else { return }
            commandQueue = device.makeCommandQueue()
            ciContext = CIContext(mtlDevice: device)
            consumeTask = Task { [weak self, weak view] in
                for await texture in stream {
                    guard let self, let view else { return }
                    await self.render(texture: texture, into: view)
                }
            }
        }

        private func render(texture: MTLTexture, into view: MTKView) {
            guard
                let ciContext, let commandQueue,
                let drawable = view.currentDrawable,
                let commandBuffer = commandQueue.makeCommandBuffer()
            else { return }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            // MTLTexture 的行序（origin 左上）与 CIImage 默认坐标系（origin 左下）相反，
            // 不翻转的话画面会是上下颠倒的。
            let sourceImage = CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace])?
                .oriented(.downMirrored)
            guard let sourceImage else { return }

            let drawableSize = CGSize(width: drawable.texture.width, height: drawable.texture.height)
            let scaled = sourceImage.transformed(by: CGAffineTransform(
                scaleX: drawableSize.width / sourceImage.extent.width,
                y: drawableSize.height / sourceImage.extent.height
            ))

            ciContext.render(
                scaled,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: .zero, size: drawableSize),
                colorSpace: colorSpace
            )
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        deinit {
            consumeTask?.cancel()
        }
    }
}

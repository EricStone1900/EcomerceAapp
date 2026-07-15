import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

import CameraCore
import CameraPipeline
import Shared

/// quad Annotation → 透视校正 → 自动裁剪。复用分析链最近一次 quad 结果，不重复跑 Vision 请求。
///
/// 显式声明 `Sendable`（见 `ThermalPolicyUseCase` 顶部注释，同样的理由：Swift 对 public 类型的
/// 隐式 Sendable 推导不保证跨模块可靠传播）。
public struct DocumentCaptureUseCase: Sendable {

    private let cameraSource: any CameraSourceProtocol
    private let pipeline: PipelineController

    public init(cameraSource: any CameraSourceProtocol, pipeline: PipelineController) {
        self.cameraSource = cameraSource
        self.pipeline = pipeline
    }

    public func capture(latestQuad: Annotation?, targetSize: CGSize) async throws -> PhotoCaptureResult {
        let raw = try await cameraSource.capturePhoto(PhotoCaptureRequest(captureRAW: true))
        guard case .quad(_, let corners, _) = latestQuad, corners.count == 4 else {
            return raw // 无检测结果时退化为普通拍照
        }
        // 原始 DNG（raw.rawFileURL）保持不动，只对 processedFileURL（HEIC）做透视校正 + 裁剪，
        // 另存为新文件，满足"拍照输出裁剪校正件 + 原始 DNG 两份"。
        let croppedURL = try Self.writePerspectiveCorrectedHEIC(
            sourceURL: raw.processedFileURL, corners: corners, targetSize: targetSize
        )
        return PhotoCaptureResult(processedFileURL: croppedURL, rawFileURL: raw.rawFileURL)
    }

    /// corners 顺序沿用 CameraVision.DocumentAnalyzer 的输出（[topLeft, topRight, bottomRight, bottomLeft]，
    /// Vision 归一化坐标、左下原点），与 CIPerspectiveCorrectionFilter 期望的四个角点顺序一致，
    /// 也与 CIImage 的坐标系原点一致，不需要额外翻转 y 轴（跟 CoordinateConverter 那条转屏幕坐标的
    /// 链路是两回事——这里全程留在图像自己的坐标系里，不涉及预览层）。
    private static func writePerspectiveCorrectedHEIC(
        sourceURL: URL, corners: [CGPoint], targetSize: CGSize
    ) throws -> URL {
        guard let sourceImage = CIImage(contentsOf: sourceURL) else {
            throw CameraError.captureFailed(underlying: nil)
        }
        let extent = sourceImage.extent
        let pixelCorners = corners.map { CGPoint(x: $0.x * extent.width, y: $0.y * extent.height) }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = sourceImage
        filter.topLeft = pixelCorners[0]
        filter.topRight = pixelCorners[1]
        filter.bottomRight = pixelCorners[2]
        filter.bottomLeft = pixelCorners[3]
        guard let correctedImage = filter.outputImage, !correctedImage.extent.isEmpty else {
            throw CameraError.captureFailed(underlying: nil)
        }

        // 校正后的 extent 尺寸等于四边形本身的像素尺寸（不是 targetSize），且 origin 不一定是
        // (0, 0)——先平移回原点再按 targetSize 缩放，最后裁掉浮点误差可能带出的多余边缘。
        let correctedExtent = correctedImage.extent
        let scale = CGAffineTransform(translationX: -correctedExtent.origin.x, y: -correctedExtent.origin.y)
            .concatenating(CGAffineTransform(
                scaleX: targetSize.width / correctedExtent.width,
                y: targetSize.height / correctedExtent.height
            ))
        let outputImage = correctedImage.transformed(by: scale)
            .cropped(to: CGRect(origin: .zero, size: targetSize))

        // CIContext.writeHEIFRepresentation(of:to:...) 走的是 PhotoCompressionSession，依赖硬件
        // HEVC 编码器；在没有该硬件路径的机器上（本仓库 CLI 验证用的 macOS host 就属于这种）会
        // 直接抛错。改用 CIContext.createCGImage 先转成 CGImage，再走 ImageIO 的
        // CGImageDestination 写 HEIC——这条路径不依赖硬件编码器，真机（有硬件编码器）和 CLI 验证
        // 用的 macOS host 都能跑通，是同一份代码，不是"仅真机"的降级分支。
        let context = CIContext()
        guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw CameraError.captureFailed(underlying: nil)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("heic")
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL, UTType.heic.identifier as CFString, 1, nil
        ) else {
            throw CameraError.captureFailed(underlying: nil)
        }
        CGImageDestinationAddImage(destination, outputCGImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CameraError.captureFailed(underlying: nil)
        }
        return outputURL
    }
}

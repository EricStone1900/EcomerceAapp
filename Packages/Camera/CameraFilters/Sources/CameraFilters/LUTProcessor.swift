import CoreImage
import Foundation
@preconcurrency import Metal

import CameraPipeline

public enum CameraFiltersError: Error, Sendable, Equatable {
    case invalidCubeFile(String)
    case filterUnavailable(String)
}

/// 解析 Adobe `.cube` 格式的 3D LUT 文件，用系统内建的 `CIColorCube` 滤镜做颜色变换。
///
/// 不是计划文档里设想的"手写 Metal compute shader 采样 3D 纹理"——理由跟
/// `CameraUI.ProcessedPreviewContainer` 选 `CIContext` 而不是手写 shader 一样：`CIColorCube`
/// 本来就是系统提供的、专门做这件事的滤镜，用它规避在 SPM 包里管理 `.metal` shader 编译这条
/// 额外出错面，换来的效果完全等价（GPU 侧 3D LUT 采样）。
public struct LUTProcessor: FrameProcessor, @unchecked Sendable {

    public let id: PluginID
    private let filter: CIFilter
    private let ciContext: CIContext

    public init(id: PluginID, cubeFileURL: URL, ciContext: CIContext) throws {
        self.id = id
        self.ciContext = ciContext
        let cube = try Self.parseCubeFile(at: cubeFileURL)
        guard let filter = CIFilter(name: "CIColorCube") else {
            throw CameraFiltersError.filterUnavailable("CIColorCube")
        }
        filter.setValue(cube.dimension, forKey: "inputCubeDimension")
        filter.setValue(cube.data, forKey: "inputCubeData")
        self.filter = filter
    }

    public func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture {
        renderProcessedTexture(from: texture, context: context, ciContext: ciContext) { image in
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage
        }
    }

    struct ParsedCube {
        let dimension: Int
        let data: Data
    }

    /// `.cube` 文本格式：`LUT_3D_SIZE N` 声明立方体边长，随后 N^3 行 `"R G B"`（0...1 浮点），
    /// 按规范固定顺序排列（R 变化最慢、B 变化最快）——这个顺序正好和 `CIColorCube` 期望的
    /// `inputCubeData` 排布一致，不需要重新排序，只需要把每个 RGB 三元组补一个恒为 1 的 alpha
    /// 分量、拼成连续的 Float32 数据。`TITLE`/`DOMAIN_MIN`/`DOMAIN_MAX`/`#注释` 按规范允许出现，
    /// 直接跳过。
    static func parseCubeFile(at url: URL) throws -> ParsedCube {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parseCubeText(text)
    }

    static func parseCubeText(_ text: String) throws -> ParsedCube {
        var dimension: Int?
        var values: [Float] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("LUT_3D_SIZE") {
                let parts = line.split(separator: " ")
                guard parts.count == 2, let size = Int(parts[1]) else {
                    throw CameraFiltersError.invalidCubeFile("malformed LUT_3D_SIZE line: \(line)")
                }
                dimension = size
                continue
            }
            if line.hasPrefix("TITLE") || line.hasPrefix("DOMAIN_MIN") || line.hasPrefix("DOMAIN_MAX") {
                continue
            }

            let components = line.split(separator: " ").compactMap { Float($0) }
            guard components.count == 3 else {
                throw CameraFiltersError.invalidCubeFile("expected 3 float components, got: \(line)")
            }
            values.append(contentsOf: components + [1]) // RGB -> RGBA，alpha 固定 1
        }

        guard let dimension else {
            throw CameraFiltersError.invalidCubeFile("missing LUT_3D_SIZE")
        }
        let expectedCount = dimension * dimension * dimension * 4
        guard values.count == expectedCount else {
            throw CameraFiltersError.invalidCubeFile(
                "expected \(expectedCount) floats for a \(dimension)^3 cube, got \(values.count)"
            )
        }
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return ParsedCube(dimension: dimension, data: data)
    }
}

import Accelerate
import CoreVideo

/// 第一个内建 FrameAnalyzer 实现，不依赖 Vision framework，验证分析链的丢帧调度是否生效。
public struct HistogramAnalyzer: FrameAnalyzer {

    public let id = PluginID("histogram")
    public let preferredFPS: Int
    private let bucketCount: Int

    public init(preferredFPS: Int = 10, bucketCount: Int = 32) {
        self.preferredFPS = preferredFPS
        self.bucketCount = bucketCount
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        [.histogram(Self.computeHistogram(pixelBuffer: frame.pixelBuffer, bucketCount: bucketCount))]
    }

    // vImage 直方图统计只认交错 8-bit 4-channel 源，CameraSession 已经显式把 videoDataOutput 配成了
    // kCVPixelFormatType_32BGRA（内存字节序 B/G/R/A），不匹配的像素格式直接返回空 bucket 而不是崩溃——
    // 空 bucket 本身也是 OverlayCanvas 已经处理过的合法状态（数组为空就不画曲线）。
    static func computeHistogram(pixelBuffer: CVPixelBuffer, bucketCount: Int) -> HistogramData {
        let empty = HistogramData(redBuckets: [], greenBuckets: [], blueBuckets: [], luminanceBuckets: [])
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else { return empty }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return empty }

        var sourceBuffer = vImage_Buffer(
            data: baseAddress,
            height: vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer)),
            width: vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer)),
            rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer)
        )

        // 4 个 channel 直方图，按内存字节序对应 B/G/R/A（不是按 "ARGB8888" 这个 API 名字面意义）。
        var blueCounts = [vImagePixelCount](repeating: 0, count: 256)
        var greenCounts = [vImagePixelCount](repeating: 0, count: 256)
        var redCounts = [vImagePixelCount](repeating: 0, count: 256)
        var alphaCounts = [vImagePixelCount](repeating: 0, count: 256)

        let histogramError = blueCounts.withUnsafeMutableBufferPointer { bluePtr in
            greenCounts.withUnsafeMutableBufferPointer { greenPtr in
                redCounts.withUnsafeMutableBufferPointer { redPtr in
                    alphaCounts.withUnsafeMutableBufferPointer { alphaPtr in
                        var histogramPointers: [UnsafeMutablePointer<vImagePixelCount>?] = [
                            bluePtr.baseAddress, greenPtr.baseAddress, redPtr.baseAddress, alphaPtr.baseAddress
                        ]
                        return vImageHistogramCalculation_ARGB8888(&sourceBuffer, &histogramPointers, vImage_Flags(kvImageNoFlags))
                    }
                }
            }
        }
        guard histogramError == kvImageNoError else { return empty }

        let luminanceCounts = luminanceHistogram(source: sourceBuffer)

        return HistogramData(
            redBuckets: downsample(redCounts, bucketCount: bucketCount),
            greenBuckets: downsample(greenCounts, bucketCount: bucketCount),
            blueBuckets: downsample(blueCounts, bucketCount: bucketCount),
            luminanceBuckets: downsample(luminanceCounts, bucketCount: bucketCount)
        )
    }

    /// 用标准 luma 权重（R*0.299 + G*0.587 + B*0.114）把 BGRA 转成单通道 8-bit 亮度平面再统计——
    /// 直方图不能靠"分别统计 R/G/B 再加权平均 bucket"凑出来（那是对分布做线性组合，数学上不等于
    /// 对像素值先加权求亮度再统计分布），所以这里老老实实先转平面图再统计。
    private static func luminanceHistogram(source: vImage_Buffer) -> [vImagePixelCount] {
        var mutableSource = source
        let byteCount = Int(source.height) * Int(source.width)
        guard byteCount > 0, let luminanceData = malloc(byteCount) else {
            return [vImagePixelCount](repeating: 0, count: 256)
        }
        defer { free(luminanceData) }

        var destBuffer = vImage_Buffer(
            data: luminanceData, height: source.height, width: source.width, rowBytes: Int(source.width)
        )
        // 权重顺序对应源 buffer 的内存字节序 B/G/R/A：0.114/0.587/0.299/0，分母 256 做定点换算。
        var matrix: [Int16] = [29, 150, 77, 0]
        let conversionError = vImageMatrixMultiply_ARGB8888ToPlanar8(
            &mutableSource, &destBuffer, &matrix, 256, nil, 0, vImage_Flags(kvImageNoFlags)
        )
        guard conversionError == kvImageNoError else {
            return [vImagePixelCount](repeating: 0, count: 256)
        }

        var counts = [vImagePixelCount](repeating: 0, count: 256)
        let histogramError = counts.withUnsafeMutableBufferPointer { ptr -> vImage_Error in
            guard let base = ptr.baseAddress else { return vImage_Error(kvImageInvalidParameter) }
            return vImageHistogramCalculation_Planar8(&destBuffer, base, vImage_Flags(kvImageNoFlags))
        }
        guard histogramError == kvImageNoError else {
            return [vImagePixelCount](repeating: 0, count: 256)
        }
        return counts
    }

    /// 256 个原始 bin 压缩成 bucketCount 个展示用 bucket（求和后按各自通道的最大值归一化到 [0, 1]），
    /// 供 OverlayCanvas 直接拿来画曲线，不需要 UI 层再关心原始计数量级。
    private static func downsample(_ histogram: [vImagePixelCount], bucketCount: Int) -> [Float] {
        guard bucketCount > 0 else { return [] }
        let groupSize = max(1, histogram.count / bucketCount)
        var buckets: [Float] = []
        buckets.reserveCapacity(bucketCount)
        var index = 0
        while index < histogram.count {
            let end = min(index + groupSize, histogram.count)
            buckets.append(Float(histogram[index..<end].reduce(0, +)))
            index = end
        }
        let maxValue = buckets.max() ?? 0
        guard maxValue > 0 else { return buckets.map { _ in 0 } }
        return buckets.map { $0 / maxValue }
    }
}

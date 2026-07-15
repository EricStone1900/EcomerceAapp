import Vision

import CameraPipeline

/// 卡片检测：固定长宽比约束的矩形检测，复用 DocumentAnalyzer 相同的 VNDetectRectanglesRequest，
/// 区别在于 aspectRatio 约束（信用卡/身份证比例）。
public struct CardAnalyzer: FrameAnalyzer {

    public let id = PluginID("card")
    public let preferredFPS: Int
    private let aspectRatio: ClosedRange<Float>

    public init(preferredFPS: Int = 8, aspectRatio: ClosedRange<Float> = 1.4...1.6) {
        self.preferredFPS = preferredFPS
        self.aspectRatio = aspectRatio
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = aspectRatio.lowerBound
        request.maximumAspectRatio = aspectRatio.upperBound
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.pixelBuffer, orientation: frame.orientation, options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).map { observation in
            .quad(
                id: UUID(),
                corners: [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft],
                confidence: observation.confidence
            )
        }
    }
}

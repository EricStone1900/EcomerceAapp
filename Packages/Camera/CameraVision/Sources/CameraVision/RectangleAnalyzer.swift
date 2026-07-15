import Vision

import CameraPipeline

/// 通用矩形检测：无长宽比约束，产出 quad Annotation。
public struct RectangleAnalyzer: FrameAnalyzer {

    public let id = PluginID("rectangle")
    public let preferredFPS: Int

    public init(preferredFPS: Int = 8) {
        self.preferredFPS = preferredFPS
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 4

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

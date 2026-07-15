import Vision

import CameraPipeline

/// 文档检测：产出四边形 Annotation，归一化坐标（左下原点，与 Vision 原生坐标系一致）。
public struct DocumentAnalyzer: FrameAnalyzer {

    public let id = PluginID("document")
    public let preferredFPS: Int

    public init(preferredFPS: Int = 8) {
        self.preferredFPS = preferredFPS
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.7
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

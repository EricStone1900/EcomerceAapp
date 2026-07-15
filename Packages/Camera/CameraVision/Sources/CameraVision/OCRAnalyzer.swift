import CoreGraphics
import Vision

import CameraPipeline

/// OCR 识别结果的统一模型，随 Annotation.custom(key: "ocr", payload:) 传出。
public struct RecognizedText: Sendable {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float
}

/// 文字识别：产出 .custom(key: "ocr", payload: [RecognizedText])，V5 扩展口的一个具体用法示例。
public struct OCRAnalyzer: FrameAnalyzer {

    public let id = PluginID("ocr")
    public let preferredFPS: Int

    public init(preferredFPS: Int = 4) {
        self.preferredFPS = preferredFPS
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast

        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.pixelBuffer, orientation: frame.orientation, options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let recognized: [RecognizedText] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedText(text: candidate.string, boundingBox: observation.boundingBox, confidence: candidate.confidence)
        }
        guard !recognized.isEmpty else { return [] }
        return [.custom(key: "ocr", payload: recognized)]
    }
}

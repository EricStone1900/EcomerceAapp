import Vision

import CameraPipeline

/// 条码/二维码检测：产出 .objects([DetectedObject])，label 为条码 payload 内容。
public struct BarcodeAnalyzer: FrameAnalyzer {

    public let id = PluginID("barcode")
    public let preferredFPS: Int

    public init(preferredFPS: Int = 8) {
        self.preferredFPS = preferredFPS
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNDetectBarcodesRequest()

        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.pixelBuffer, orientation: frame.orientation, options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let objects = (request.results ?? []).map { observation in
            DetectedObject(
                label: observation.payloadStringValue ?? observation.symbology.rawValue,
                boundingBox: observation.boundingBox,
                confidence: observation.confidence
            )
        }
        guard !objects.isEmpty else { return [] }
        return [.objects(objects)]
    }
}

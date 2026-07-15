import Vision

import CameraPipeline

/// 人脸检测：产出 .objects([DetectedObject])。
public struct FaceAnalyzer: FrameAnalyzer {

    public let id = PluginID("face")
    public let preferredFPS: Int

    public init(preferredFPS: Int = 8) {
        self.preferredFPS = preferredFPS
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.pixelBuffer, orientation: frame.orientation, options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let objects = (request.results ?? []).map { observation in
            DetectedObject(label: "face", boundingBox: observation.boundingBox, confidence: observation.confidence)
        }
        guard !objects.isEmpty else { return [] }
        return [.objects(objects)]
    }
}

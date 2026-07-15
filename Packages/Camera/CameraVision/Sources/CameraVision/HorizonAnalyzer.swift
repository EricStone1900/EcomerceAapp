import Vision

import CameraPipeline

/// 水平仪检测：产出 .horizon(angle:)，角度单位为度（degrees），与 CameraUI.OverlayCanvas 的
/// 绘制约定一致——Vision 的 VNHorizonObservation.angle 是弧度，这里做单位换算。
public struct HorizonAnalyzer: FrameAnalyzer {

    public let id = PluginID("horizon")
    public let preferredFPS: Int

    public init(preferredFPS: Int = 8) {
        self.preferredFPS = preferredFPS
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        let request = VNDetectHorizonRequest()

        let handler = VNImageRequestHandler(
            cvPixelBuffer: frame.pixelBuffer, orientation: frame.orientation, options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let observation = request.results?.first else { return [] }
        let degrees = Double(observation.angle) * 180 / .pi
        return [.horizon(angle: degrees)]
    }
}

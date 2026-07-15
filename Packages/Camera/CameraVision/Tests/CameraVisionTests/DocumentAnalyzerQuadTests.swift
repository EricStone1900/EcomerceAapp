import CoreGraphics
import CoreMedia
import CoreVideo
import ImageIO
import Testing

import CameraPipeline
@testable import CameraVision

private func makeBlankFrame(width: Int = 64, height: Int = 64) -> Frame {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    return Frame(
        pixelBuffer: pixelBuffer!,
        timestamp: .zero,
        orientation: .up,
        cameraMetadata: FrameMetadata(iso: 100, shutterDuration: .zero, lensPosition: 0, intrinsics: nil)
    )
}

@Suite("DocumentAnalyzer")
struct DocumentAnalyzerQuadTests {

    @Test("identity and preferredFPS are stable")
    func identityIsStable() {
        let analyzer = DocumentAnalyzer(preferredFPS: 6)

        #expect(analyzer.id == PluginID("document"))
        #expect(analyzer.preferredFPS == 6)
    }

    @Test("a blank frame with no rectangles produces no quad annotations")
    func blankFrameProducesNoAnnotations() async {
        let analyzer = DocumentAnalyzer()

        let annotations = await analyzer.analyze(makeBlankFrame())

        #expect(annotations.isEmpty)
    }
}

@Suite("CardAnalyzer")
struct CardAnalyzerTests {

    @Test("identity and preferredFPS are stable")
    func identityIsStable() {
        let analyzer = CardAnalyzer(preferredFPS: 6, aspectRatio: 1.5...1.6)

        #expect(analyzer.id == PluginID("card"))
        #expect(analyzer.preferredFPS == 6)
    }

    @Test("a blank frame with no rectangles produces no quad annotations")
    func blankFrameProducesNoAnnotations() async {
        let analyzer = CardAnalyzer()

        let annotations = await analyzer.analyze(makeBlankFrame())

        #expect(annotations.isEmpty)
    }
}

@Suite("Other CameraVision analyzers on a blank frame")
struct BlankFrameAnalyzerTests {

    @Test("RectangleAnalyzer produces no annotations")
    func rectangleAnalyzer() async {
        let annotations = await RectangleAnalyzer().analyze(makeBlankFrame())
        #expect(annotations.isEmpty)
    }

    @Test("OCRAnalyzer produces no annotations")
    func ocrAnalyzer() async {
        let annotations = await OCRAnalyzer().analyze(makeBlankFrame())
        #expect(annotations.isEmpty)
    }

    @Test("BarcodeAnalyzer produces no annotations")
    func barcodeAnalyzer() async {
        let annotations = await BarcodeAnalyzer().analyze(makeBlankFrame())
        #expect(annotations.isEmpty)
    }

    @Test("FaceAnalyzer produces no annotations")
    func faceAnalyzer() async {
        let annotations = await FaceAnalyzer().analyze(makeBlankFrame())
        #expect(annotations.isEmpty)
    }

    @Test("HorizonAnalyzer identity is stable")
    func horizonAnalyzerIdentity() {
        let analyzer = HorizonAnalyzer(preferredFPS: 3)
        #expect(analyzer.id == PluginID("horizon"))
        #expect(analyzer.preferredFPS == 3)
    }
}

import CoreVideo
import Testing

@testable import CameraPipeline

@Suite("HistogramAnalyzer")
struct HistogramAnalyzerTests {

    @Test("analyze produces a single histogram annotation")
    func analyzeReturnsHistogramAnnotation() async {
        let analyzer = HistogramAnalyzer()

        let annotations = await analyzer.analyze(makeTestFrame())

        #expect(annotations.count == 1)
        guard case .histogram = annotations.first else {
            Issue.record("expected a .histogram annotation, got \(String(describing: annotations.first))")
            return
        }
    }

    @Test("id and preferredFPS are stable")
    func identityIsStable() {
        let analyzer = HistogramAnalyzer(preferredFPS: 5)

        #expect(analyzer.id == PluginID("histogram"))
        #expect(analyzer.preferredFPS == 5)
    }

    @Test("a solid red frame produces a red histogram peaking at the top bucket and empty green/blue")
    func solidRedFrameProducesExpectedHistogram() async {
        let analyzer = HistogramAnalyzer(bucketCount: 32)
        let frame = makeSolidColorFrame(width: 8, height: 8, blue: 0, green: 0, red: 255)

        let annotations = await analyzer.analyze(frame)

        guard case .histogram(let data) = annotations.first else {
            Issue.record("expected a .histogram annotation")
            return
        }
        #expect(data.redBuckets.count == 32)
        #expect(peakIndex(data.redBuckets) == 31)
        #expect(peakIndex(data.greenBuckets) == 0)
        #expect(peakIndex(data.blueBuckets) == 0)
        // 纯红像素的亮度是 R*0.299，既不是全黑也不是全白，应该落在中间某个 bucket。
        let luminancePeak = peakIndex(data.luminanceBuckets)
        #expect(luminancePeak > 0 && luminancePeak < 31)
    }

    @Test("a solid white frame peaks at the top bucket on every channel including luminance")
    func solidWhiteFrameProducesExpectedHistogram() async {
        let analyzer = HistogramAnalyzer(bucketCount: 32)
        let frame = makeSolidColorFrame(width: 8, height: 8, blue: 255, green: 255, red: 255)

        let annotations = await analyzer.analyze(frame)

        guard case .histogram(let data) = annotations.first else {
            Issue.record("expected a .histogram annotation")
            return
        }
        #expect(peakIndex(data.redBuckets) == 31)
        #expect(peakIndex(data.greenBuckets) == 31)
        #expect(peakIndex(data.blueBuckets) == 31)
        #expect(peakIndex(data.luminanceBuckets) == 31)
    }

    @Test("an unsupported pixel format returns empty buckets instead of crashing")
    func unsupportedPixelFormatReturnsEmptyBuckets() async {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        let frame = Frame(
            pixelBuffer: pixelBuffer!,
            timestamp: .zero,
            orientation: .up,
            cameraMetadata: FrameMetadata(iso: 100, shutterDuration: .zero, lensPosition: 0, intrinsics: nil)
        )

        let annotations = await HistogramAnalyzer().analyze(frame)

        guard case .histogram(let data) = annotations.first else {
            Issue.record("expected a .histogram annotation")
            return
        }
        #expect(data.redBuckets.isEmpty)
        #expect(data.greenBuckets.isEmpty)
        #expect(data.blueBuckets.isEmpty)
        #expect(data.luminanceBuckets.isEmpty)
    }

    private func peakIndex(_ buckets: [Float]) -> Int {
        buckets.enumerated().max(by: { $0.element < $1.element })?.offset ?? -1
    }
}

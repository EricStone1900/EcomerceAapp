import CoreGraphics
import Testing

@testable import Shared

private struct FixedFrameProvider: CALayerFrameProviding {
    let layerFrame: CGRect
}

@Suite("CoordinateConverter")
struct CoordinateConverterTests {

    @Test("normalized point flips y and scales to layer bounds")
    func convertsNormalizedPointToLayerCoordinates() {
        let converter = CoordinateConverter(previewLayer: FixedFrameProvider(layerFrame: CGRect(x: 0, y: 0, width: 200, height: 100)))

        let point = converter.convert(normalizedPoint: CGPoint(x: 0.25, y: 0.75))

        #expect(point.x == 50)
        #expect(point.y == 25)
    }

    @Test("bottom-left origin normalized point maps to top-left of layer")
    func flipsYAxis() {
        let converter = CoordinateConverter(previewLayer: FixedFrameProvider(layerFrame: CGRect(x: 0, y: 0, width: 100, height: 100)))

        let point = converter.convert(normalizedPoint: CGPoint(x: 0, y: 0))

        #expect(point == CGPoint(x: 0, y: 100))
    }

    @Test("aspect-fill: wider layer than image crops the image's top and bottom")
    func aspectFillCropsVertically() {
        // layer 200x100（2:1），图像 100x100（1:1）——图像被放大到 200x200 铺满宽度，
        // 上下各溢出 50pt 被裁掉。图像中心 (0.5, 0.5) 映射到放大后图像的 (100, 100)，
        // 减去顶部裁掉的 50pt 偏移后落在 layer 坐标 (100, 50)。
        let converter = CoordinateConverter(previewLayer: FixedFrameProvider(layerFrame: CGRect(x: 0, y: 0, width: 200, height: 100)))

        let center = converter.convert(normalizedPoint: CGPoint(x: 0.5, y: 0.5), uprightImageSize: CGSize(width: 100, height: 100))
        #expect(center == CGPoint(x: 100, y: 50))

        // 图像左上角 (0, 1) 翻转后是 flipped (0, 0)，放大裁切后应该落在 layer 顶部之上（负 y，被裁掉的部分）。
        let topLeft = converter.convert(normalizedPoint: CGPoint(x: 0, y: 1), uprightImageSize: CGSize(width: 100, height: 100))
        #expect(topLeft == CGPoint(x: 0, y: -50))
    }

    @Test("aspect-fill: taller layer than image crops the image's left and right")
    func aspectFillCropsHorizontally() {
        // layer 100x200（1:2），图像 100x100（1:1）——图像放大到 200x200 铺满高度，
        // 左右各溢出 50pt 被裁掉，中心点落在 layer 坐标 (50, 100)。
        let converter = CoordinateConverter(previewLayer: FixedFrameProvider(layerFrame: CGRect(x: 0, y: 0, width: 100, height: 200)))

        let center = converter.convert(normalizedPoint: CGPoint(x: 0.5, y: 0.5), uprightImageSize: CGSize(width: 100, height: 100))
        #expect(center == CGPoint(x: 50, y: 100))
    }

    @Test("zero image size falls back to plain scaling without crashing")
    func zeroImageSizeFallsBackToPlainScaling() {
        let converter = CoordinateConverter(previewLayer: FixedFrameProvider(layerFrame: CGRect(x: 0, y: 0, width: 200, height: 100)))

        let point = converter.convert(normalizedPoint: CGPoint(x: 0.25, y: 0.75), uprightImageSize: .zero)

        #expect(point.x == 50)
        #expect(point.y == 25)
    }
}

@Suite("GeometryUtils.EMAFilter")
struct EMAFilterTests {

    @Test("first update returns the input unchanged")
    func firstUpdateIsUnchanged() {
        var filter = GeometryUtils.EMAFilter(alpha: 0.3)

        let result = filter.update(CGPoint(x: 10, y: 10))

        #expect(result == CGPoint(x: 10, y: 10))
    }

    @Test("subsequent updates smooth toward the new value")
    func smoothsTowardNewValue() {
        var filter = GeometryUtils.EMAFilter(alpha: 0.5)
        _ = filter.update(CGPoint(x: 0, y: 0))

        let result = filter.update(CGPoint(x: 10, y: 0))

        #expect(result == CGPoint(x: 5, y: 0))
    }
}

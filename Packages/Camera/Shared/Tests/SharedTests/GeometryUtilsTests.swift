import CoreGraphics
import Testing

@testable import Shared

@Suite("GeometryUtils.perspectiveTransform")
struct PerspectiveTransformTests {

    @Test("axis-aligned quad maps to a pure scale transform")
    func axisAlignedQuadProducesScaleTransform() {
        let corners = [
            CGPoint(x: 0, y: 0),  // topLeft
            CGPoint(x: 1, y: 0),  // topRight
            CGPoint(x: 1, y: 1),  // bottomRight (not used by the 3-point affine solve)
            CGPoint(x: 0, y: 1),  // bottomLeft
        ]

        let transform = GeometryUtils.perspectiveTransform(quad: corners, targetSize: CGSize(width: 100, height: 200))

        #expect(transform.a == 100)
        #expect(transform.d == 200)
        #expect(transform.b == 0)
        #expect(transform.c == 0)
        #expect(transform.tx == 0)
        #expect(transform.ty == 0)
    }

    @Test("transform maps the three solved corners exactly onto the target rectangle")
    func solvedCornersMapExactly() {
        let corners = [
            CGPoint(x: 10, y: 20),
            CGPoint(x: 50, y: 15),
            CGPoint(x: 55, y: 80),
            CGPoint(x: 5, y: 75),
        ]
        let targetSize = CGSize(width: 300, height: 400)

        let transform = GeometryUtils.perspectiveTransform(quad: corners, targetSize: targetSize)

        let mappedTopLeft = corners[0].applying(transform)
        let mappedTopRight = corners[1].applying(transform)
        let mappedBottomLeft = corners[3].applying(transform)

        #expect(abs(mappedTopLeft.x - 0) < 0.001)
        #expect(abs(mappedTopLeft.y - 0) < 0.001)
        #expect(abs(mappedTopRight.x - targetSize.width) < 0.001)
        #expect(abs(mappedTopRight.y - 0) < 0.001)
        #expect(abs(mappedBottomLeft.x - 0) < 0.001)
        #expect(abs(mappedBottomLeft.y - targetSize.height) < 0.001)
    }

    @Test("degenerate (collinear) quad falls back to the identity transform")
    func degenerateQuadFallsBackToIdentity() {
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 2, y: 0),  // topLeft/topRight/bottomLeft collinear -> singular matrix
        ]

        let transform = GeometryUtils.perspectiveTransform(quad: corners, targetSize: CGSize(width: 100, height: 100))

        #expect(transform == .identity)
    }
}

@Suite("GeometryUtils.QuadEMAFilter")
struct QuadEMAFilterTests {

    @Test("first update returns corners unchanged")
    func firstUpdateIsUnchanged() {
        var filter = GeometryUtils.QuadEMAFilter(alpha: 0.3)
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)]

        let result = filter.update(corners)

        #expect(result == corners)
    }

    @Test("each corner is smoothed independently")
    func cornersAreSmoothedIndependently() {
        var filter = GeometryUtils.QuadEMAFilter(alpha: 0.5)
        let first = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0)]
        _ = filter.update(first)

        let second = [CGPoint(x: 10, y: 0), CGPoint(x: 0, y: 20), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0)]
        let result = filter.update(second)

        #expect(result[0] == CGPoint(x: 5, y: 0))
        #expect(result[1] == CGPoint(x: 0, y: 10))
        #expect(result[2] == CGPoint(x: 0, y: 0))
        #expect(result[3] == CGPoint(x: 0, y: 0))
    }
}

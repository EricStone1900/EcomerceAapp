import CoreGraphics
import Testing

@testable import CameraPipeline

@Suite("Frame.uprightImageSize")
struct FrameUprightImageSizeTests {

    @Test("up/down orientations keep the buffer's raw width/height")
    func uprightOrientationsKeepRawSize() {
        #expect(makeTestFrame(width: 400, height: 300, orientation: .up).uprightImageSize == CGSize(width: 400, height: 300))
        #expect(makeTestFrame(width: 400, height: 300, orientation: .down).uprightImageSize == CGSize(width: 400, height: 300))
        #expect(makeTestFrame(width: 400, height: 300, orientation: .upMirrored).uprightImageSize == CGSize(width: 400, height: 300))
        #expect(makeTestFrame(width: 400, height: 300, orientation: .downMirrored).uprightImageSize == CGSize(width: 400, height: 300))
    }

    @Test("left/right orientations swap width and height (90 degree rotation)")
    func rotatedOrientationsSwapDimensions() {
        #expect(makeTestFrame(width: 400, height: 300, orientation: .left).uprightImageSize == CGSize(width: 300, height: 400))
        #expect(makeTestFrame(width: 400, height: 300, orientation: .right).uprightImageSize == CGSize(width: 300, height: 400))
        #expect(makeTestFrame(width: 400, height: 300, orientation: .leftMirrored).uprightImageSize == CGSize(width: 300, height: 400))
        #expect(makeTestFrame(width: 400, height: 300, orientation: .rightMirrored).uprightImageSize == CGSize(width: 300, height: 400))
    }
}

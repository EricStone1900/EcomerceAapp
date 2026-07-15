import CoreImage
import Testing

import CameraPipeline
@testable import CameraFilters

@Suite("CIFilterProcessor")
struct CIFilterProcessorTests {

    @Test("CIColorInvert inverts a solid red texture to cyan")
    func invertsColor() throws {
        let (device, commandQueue) = try makeRenderFixture()
        let input = try makeSolidTexture(device: device, color: (255, 0, 0, 255))
        let filter = try #require(CIFilter(name: "CIColorInvert"))
        let processor = CIFilterProcessor(id: PluginID("invert"), filter: filter, ciContext: CIContext(mtlDevice: device))

        let output = try runProcessor(processor, on: input, device: device, commandQueue: commandQueue)

        let pixel = readPixel(output)
        #expect(pixel.0 < 10)    // red -> ~0
        #expect(pixel.1 > 245)   // green -> ~255
        #expect(pixel.2 > 245)   // blue -> ~255
        #expect(pixel.3 > 245)   // alpha untouched by CIColorInvert
    }

    @Test("id is stable")
    func idIsStable() {
        let filter = CIFilter(name: "CIColorInvert")!
        let processor = CIFilterProcessor(id: PluginID("invert"), filter: filter, ciContext: CIContext())

        #expect(processor.id == PluginID("invert"))
    }
}

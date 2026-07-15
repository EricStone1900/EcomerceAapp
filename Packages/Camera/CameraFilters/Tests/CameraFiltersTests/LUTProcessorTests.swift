import CoreImage
import Foundation
import Testing

import CameraPipeline
@testable import CameraFilters

// 2x2x2 恒等 LUT：每个格点的输出值就是格点自己的坐标。
private let identityCubeText = """
LUT_3D_SIZE 2
0.0 0.0 0.0
1.0 0.0 0.0
0.0 1.0 0.0
1.0 1.0 0.0
0.0 0.0 1.0
1.0 0.0 1.0
0.0 1.0 1.0
1.0 1.0 1.0
"""

// 2x2x2 反色 LUT：格点 (r,g,b) 的输出是 (1-r,1-g,1-b)。白/黑两个对角格点在任何轴序约定下
// 都不受"哪个轴变化最快"这个歧义影响（因为三个坐标分量相等），用它俩验证 LUT 数据被正确应用，
// 不用纠结 .cube 文件的轴序约定是否和 CIColorCube 的内部约定完全一致。
private let invertCubeText = """
LUT_3D_SIZE 2
1.0 1.0 1.0
0.0 1.0 1.0
1.0 0.0 1.0
0.0 0.0 1.0
1.0 1.0 0.0
0.0 1.0 0.0
1.0 0.0 0.0
0.0 0.0 0.0
"""

private func writeTempCubeFile(_ text: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("cube")
    try text.write(to: url, atomically: true, encoding: .utf8)
    return url
}

@Suite("LUTProcessor.parseCubeText")
struct LUTProcessorParsingTests {

    @Test("parses LUT_3D_SIZE and RGB rows into a flat RGBA Float32 buffer")
    func parsesValidCube() throws {
        let cube = try LUTProcessor.parseCubeText(identityCubeText)

        #expect(cube.dimension == 2)
        #expect(cube.data.count == 2 * 2 * 2 * 4 * MemoryLayout<Float>.size)
    }

    @Test("throws on a missing LUT_3D_SIZE header")
    func throwsOnMissingSize() {
        #expect(throws: CameraFiltersError.self) {
            try LUTProcessor.parseCubeText("0.0 0.0 0.0\n1.0 1.0 1.0")
        }
    }

    @Test("throws when a data row doesn't have exactly 3 components")
    func throwsOnMalformedRow() {
        #expect(throws: CameraFiltersError.self) {
            try LUTProcessor.parseCubeText("LUT_3D_SIZE 2\n0.0 0.0\n1.0 1.0 1.0 1.0")
        }
    }

    @Test("ignores TITLE/DOMAIN_MIN/DOMAIN_MAX/comment lines")
    func ignoresMetadataLines() throws {
        let text = """
        TITLE "test"
        # a comment
        LUT_3D_SIZE 2
        DOMAIN_MIN 0.0 0.0 0.0
        DOMAIN_MAX 1.0 1.0 1.0
        \(identityCubeText.split(separator: "\n").dropFirst().joined(separator: "\n"))
        """
        let cube = try LUTProcessor.parseCubeText(text)

        #expect(cube.dimension == 2)
    }
}

@Suite("LUTProcessor.process")
struct LUTProcessorRenderingTests {

    @Test("an identity LUT leaves an arbitrary color unchanged")
    func identityLeavesColorUnchanged() throws {
        let (device, commandQueue) = try makeRenderFixture()
        let cubeURL = try writeTempCubeFile(identityCubeText)
        let processor = try LUTProcessor(id: PluginID("identity"), cubeFileURL: cubeURL, ciContext: CIContext(mtlDevice: device))
        let input = try makeSolidTexture(device: device, color: (128, 64, 200, 255))

        let output = try runProcessor(processor, on: input, device: device, commandQueue: commandQueue)

        let pixel = readPixel(output)
        #expect(abs(Int(pixel.0) - 128) <= 3)
        #expect(abs(Int(pixel.1) - 64) <= 3)
        #expect(abs(Int(pixel.2) - 200) <= 3)
    }

    @Test("an invert LUT maps white to black and black to white")
    func invertLUTFlipsBlackAndWhite() throws {
        let (device, commandQueue) = try makeRenderFixture()
        let cubeURL = try writeTempCubeFile(invertCubeText)
        let processor = try LUTProcessor(id: PluginID("invert"), cubeFileURL: cubeURL, ciContext: CIContext(mtlDevice: device))

        let white = try makeSolidTexture(device: device, color: (255, 255, 255, 255))
        let whiteOutput = try runProcessor(processor, on: white, device: device, commandQueue: commandQueue)
        let whitePixel = readPixel(whiteOutput)
        #expect(whitePixel.0 < 10 && whitePixel.1 < 10 && whitePixel.2 < 10)

        let black = try makeSolidTexture(device: device, color: (0, 0, 0, 255))
        let blackOutput = try runProcessor(processor, on: black, device: device, commandQueue: commandQueue)
        let blackPixel = readPixel(blackOutput)
        #expect(blackPixel.0 > 245 && blackPixel.1 > 245 && blackPixel.2 > 245)
    }

    @Test("throws when the .cube file can't be parsed")
    func throwsOnInvalidCubeFile() throws {
        let url = try writeTempCubeFile("not a valid cube file")

        #expect(throws: CameraFiltersError.self) {
            _ = try LUTProcessor(id: PluginID("bad"), cubeFileURL: url, ciContext: CIContext())
        }
    }
}

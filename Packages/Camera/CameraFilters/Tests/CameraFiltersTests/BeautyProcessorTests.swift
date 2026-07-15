import CoreImage
@preconcurrency import Metal
import Testing

import CameraPipeline
@testable import CameraFilters

@Suite("BeautyProcessor")
struct BeautyProcessorTests {

    @Test("softens a hard black/white edge instead of leaving it untouched")
    func softensHardEdge() throws {
        let (device, commandQueue) = try makeRenderFixture()
        let width = 16, height = 16
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let texture = try #require(device.makeTexture(descriptor: descriptor))

        // 左半黑、右半白，构造一条硬边缘。
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let value: UInt8 = x < width / 2 ? 0 : 255
                pixels[offset] = value
                pixels[offset + 1] = value
                pixels[offset + 2] = value
                pixels[offset + 3] = 255
            }
        }
        pixels.withUnsafeBytes { buffer in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                withBytes: buffer.baseAddress!, bytesPerRow: width * 4
            )
        }

        let processor = BeautyProcessor(ciContext: CIContext(mtlDevice: device), blurRadius: 4, blendAlpha: 0.8)
        let output = try runProcessor(processor, on: texture, device: device, commandQueue: commandQueue)

        // 硬边缘正上方（x = width/2，恰好在黑白交界）模糊前是纯黑或纯白，模糊+混合后应该变成
        // 介于两者之间的灰——证明真的做了模糊运算，不是原样返回。
        let edgePixel = readPixel(output, x: width / 2, y: height / 2)
        #expect(edgePixel.0 > 20 && edgePixel.0 < 235)

        // 远离边缘、纯色区域内部应该基本保持原色（模糊核半径 4，边缘影响到不了纹理中心以外太远）。
        let farLeftPixel = readPixel(output, x: 0, y: height / 2)
        #expect(farLeftPixel.0 < 60)
    }

    @Test("id defaults to PluginID(\"beauty\")")
    func idDefaultsToBeauty() {
        let processor = BeautyProcessor(ciContext: CIContext())

        #expect(processor.id == PluginID("beauty"))
    }
}

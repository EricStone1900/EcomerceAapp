@preconcurrency import Metal
import Testing

import CameraPipeline

/// 造一块纯色 RGBA8 纹理 + 跑完 process() 之后同步读回像素——GPU 渲染是异步的，
/// commandBuffer.commit() 之后必须 waitUntilCompleted() 才能保证 getBytes 读到的是渲染结果，
/// 不是纹理创建时的初始数据。
func makeRenderFixture() throws -> (device: MTLDevice, commandQueue: MTLCommandQueue) {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let commandQueue = try #require(device.makeCommandQueue())
    return (device, commandQueue)
}

func makeSolidTexture(
    device: MTLDevice, width: Int = 4, height: Int = 4, color: (UInt8, UInt8, UInt8, UInt8)
) throws -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
    )
    descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for index in stride(from: 0, to: pixels.count, by: 4) {
        pixels[index] = color.0
        pixels[index + 1] = color.1
        pixels[index + 2] = color.2
        pixels[index + 3] = color.3
    }
    pixels.withUnsafeBytes { buffer in
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
            withBytes: buffer.baseAddress!, bytesPerRow: width * 4
        )
    }
    return texture
}

func readPixel(_ texture: MTLTexture, x: Int = 0, y: Int = 0) -> (UInt8, UInt8, UInt8, UInt8) {
    var pixel = [UInt8](repeating: 0, count: 4)
    pixel.withUnsafeMutableBytes { buffer in
        texture.getBytes(
            buffer.baseAddress!, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0
        )
    }
    return (pixel[0], pixel[1], pixel[2], pixel[3])
}

/// 跑一个 FrameProcessor 并同步等结果落盘到 outputTexture——每个测试都要经过
/// process() -> commandBuffer.commit() -> waitUntilCompleted() 这个固定三步。
func runProcessor(
    _ processor: some FrameProcessor, on texture: MTLTexture, device: MTLDevice, commandQueue: MTLCommandQueue
) throws -> MTLTexture {
    let commandBuffer = try #require(commandQueue.makeCommandBuffer())
    let context = RenderContext(device: device, commandBuffer: commandBuffer)
    let output = processor.process(texture, context: context)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    return output
}

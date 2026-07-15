// 见 PipelineController.swift 顶部注释：Metal 协议类型未标注 Sendable，用 @preconcurrency 处理。
@preconcurrency import Metal

public struct PluginID: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MTLDevice/MTLCommandBuffer 是 Objective-C 协议类型，Metal 框架没有把它们标记为 Sendable，
// 但 RenderContext 只是每帧只读传递的值，不会被并发修改，用 @unchecked Sendable 显式声明安全。
public struct RenderContext: @unchecked Sendable {
    public let device: MTLDevice
    public let commandBuffer: MTLCommandBuffer

    public init(device: MTLDevice, commandBuffer: MTLCommandBuffer) {
        self.device = device
        self.commandBuffer = commandBuffer
    }
}

/// 渲染类：同步、必须每帧、只做 GPU 操作，禁止阻塞。
public protocol FrameProcessor: Sendable {
    var id: PluginID { get }
    func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture
}

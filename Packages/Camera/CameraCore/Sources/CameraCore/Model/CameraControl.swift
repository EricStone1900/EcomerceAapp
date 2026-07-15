import CoreGraphics
import CoreMedia
import Shared

public struct WBGains: Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float

    public init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// 统一控制指令，CameraSourceProtocol.apply(_:) 的入参。
public enum CameraControl: Sendable {
    case setISO(Float)
    case setShutter(CMTime)
    case setExposureBias(Float)
    case setWhiteBalance(WBGains)
    case focus(at: CGPoint)
    case switchLens(LensType)
    case setZoom(CGFloat)
    case setTorch(Bool)
}

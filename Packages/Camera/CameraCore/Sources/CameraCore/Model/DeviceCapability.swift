import CoreGraphics
import CoreMedia
import Shared

public struct WBGainsRange: Sendable {
    public let redRange: ClosedRange<Float>
    public let greenRange: ClosedRange<Float>
    public let blueRange: ClosedRange<Float>

    public init(redRange: ClosedRange<Float>, greenRange: ClosedRange<Float>, blueRange: ClosedRange<Float>) {
        self.redRange = redRange
        self.greenRange = greenRange
        self.blueRange = blueRange
    }
}

public struct CaptureFormatDescriptor: Sendable {
    public let dimensions: CMVideoDimensions
    public let maxFrameRate: Double

    public init(dimensions: CMVideoDimensions, maxFrameRate: Double) {
        self.dimensions = dimensions
        self.maxFrameRate = maxFrameRate
    }
}

/// 每颗镜头能力不同，手动控制与 Preset 都依赖它。切换镜头时发布新的 Capability，UI 据此重建滑杆范围。
public struct DeviceCapability: Sendable {
    public let lens: LensType
    public let isoRange: ClosedRange<Float>
    public let shutterRange: ClosedRange<CMTime>
    public let evRange: ClosedRange<Float>
    public let wbGainsRange: WBGainsRange
    public let supportsRAW: Bool
    public let supportsProRAW: Bool
    public let maxZoomFactor: CGFloat
    public let supportedFormats: [CaptureFormatDescriptor]

    public init(
        lens: LensType,
        isoRange: ClosedRange<Float>,
        shutterRange: ClosedRange<CMTime>,
        evRange: ClosedRange<Float>,
        wbGainsRange: WBGainsRange,
        supportsRAW: Bool,
        supportsProRAW: Bool,
        maxZoomFactor: CGFloat,
        supportedFormats: [CaptureFormatDescriptor]
    ) {
        self.lens = lens
        self.isoRange = isoRange
        self.shutterRange = shutterRange
        self.evRange = evRange
        self.wbGainsRange = wbGainsRange
        self.supportsRAW = supportsRAW
        self.supportsProRAW = supportsProRAW
        self.maxZoomFactor = maxZoomFactor
        self.supportedFormats = supportedFormats
    }
}

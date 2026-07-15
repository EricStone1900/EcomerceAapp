import CoreMedia
import simd

public struct FrameMetadata: Sendable {
    public let iso: Float
    public let shutterDuration: CMTime
    public let lensPosition: Float
    public let intrinsics: simd_float3x3?

    public init(iso: Float, shutterDuration: CMTime, lensPosition: Float, intrinsics: simd_float3x3?) {
        self.iso = iso
        self.shutterDuration = shutterDuration
        self.lensPosition = lensPosition
        self.intrinsics = intrinsics
    }
}

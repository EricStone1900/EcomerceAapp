import CoreMedia
import Testing

import CameraCore
import Shared
@testable import CameraFeature

private func makeCapability(
    isoRange: ClosedRange<Float> = 50...800,
    evRange: ClosedRange<Float> = -2...2,
    supportsRAW: Bool = true
) -> DeviceCapability {
    DeviceCapability(
        lens: .ultraWide,
        isoRange: isoRange,
        shutterRange: CMTime(value: 1, timescale: 8000)...CMTime(value: 1, timescale: 4),
        evRange: evRange,
        wbGainsRange: WBGainsRange(redRange: 1...4, greenRange: 1...4, blueRange: 1...4),
        supportsRAW: supportsRAW,
        supportsProRAW: false,
        maxZoomFactor: 2,
        supportedFormats: []
    )
}

@Suite("CapabilityValidator.clamp")
struct CapabilityValidatorTests {

    @Test("an ISO above the lens's range is clamped down to the upper bound")
    func clampsISOAboveRange() {
        let preset = CameraPreset(
            name: "Night", lens: .wide, manual: ManualSettings(iso: 3200),
            processorIDs: [], analyzerIDs: [], captureFormat: .heif
        )
        let capability = makeCapability(isoRange: 50...800)

        let clamped = CapabilityValidator.clamp(preset, capability: capability)

        #expect(clamped.manual?.iso == 800)
    }

    @Test("an ISO below the lens's range is clamped up to the lower bound")
    func clampsISOBelowRange() {
        let preset = CameraPreset(
            name: "Custom", lens: .wide, manual: ManualSettings(iso: 10),
            processorIDs: [], analyzerIDs: [], captureFormat: .heif
        )
        let capability = makeCapability(isoRange: 50...800)

        let clamped = CapabilityValidator.clamp(preset, capability: capability)

        #expect(clamped.manual?.iso == 50)
    }

    @Test("an ISO already within range is left untouched")
    func leavesInRangeISOUntouched() {
        let preset = CameraPreset(
            name: "Custom", lens: .wide, manual: ManualSettings(iso: 400),
            processorIDs: [], analyzerIDs: [], captureFormat: .heif
        )
        let capability = makeCapability(isoRange: 50...800)

        let clamped = CapabilityValidator.clamp(preset, capability: capability)

        #expect(clamped.manual?.iso == 400)
    }

    @Test("exposure bias is clamped to the lens's EV range")
    func clampsExposureBias() {
        let preset = CameraPreset(
            name: "Food", lens: .wide, manual: ManualSettings(exposureBias: 5),
            processorIDs: [], analyzerIDs: [], captureFormat: .heif
        )
        let capability = makeCapability(evRange: -2...2)

        let clamped = CapabilityValidator.clamp(preset, capability: capability)

        #expect(clamped.manual?.exposureBias == 2)
    }

    @Test("a RAW capture format is downgraded to heif when the lens doesn't support RAW")
    func downgradesCaptureFormatWhenRAWUnsupported() {
        let preset = CameraPreset(
            name: "Document", lens: .wide, manual: nil,
            processorIDs: [], analyzerIDs: [], captureFormat: .rawPlusHeif
        )
        let capability = makeCapability(supportsRAW: false)

        let clamped = CapabilityValidator.clamp(preset, capability: capability)

        #expect(clamped.captureFormat == .heif)
    }

    @Test("captureFormat is left alone when the lens supports RAW")
    func leavesCaptureFormatWhenRAWSupported() {
        let preset = CameraPreset(
            name: "Document", lens: .wide, manual: nil,
            processorIDs: [], analyzerIDs: [], captureFormat: .rawPlusHeif
        )
        let capability = makeCapability(supportsRAW: true)

        let clamped = CapabilityValidator.clamp(preset, capability: capability)

        #expect(clamped.captureFormat == .rawPlusHeif)
    }

    @Test("a preset with no manual settings is returned unchanged")
    func leavesNilManualUnchanged() {
        let preset = CameraPreset.document
        let capability = makeCapability()

        let clamped = CapabilityValidator.clamp(preset, capability: capability)

        #expect(clamped.manual == nil)
        #expect(clamped == preset)
    }
}

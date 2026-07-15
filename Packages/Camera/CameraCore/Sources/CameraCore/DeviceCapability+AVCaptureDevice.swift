@preconcurrency import AVFoundation
import CoreMedia

import Shared

extension DeviceCapability {

    /// 从真实 AVCaptureDevice + 已配置好的 AVCapturePhotoOutput 读取能力范围。
    /// 调用方需要保证 device 与 photoOutput 已经在 session 里配置完成（activeFormat 才有意义）。
    ///
    /// AVCaptureDevice.Format 的 ISO/曝光/变焦范围查询整体是 iOS-only API（Mac 摄像头没有对应的
    /// 硬件能力查询接口），macOS host 上退回一组保守的默认值——这个包依然要能在 macOS 上跑
    /// `swift build`/`swift test`（本地开发 + CI 用），但真实数值只在 iOS 上有意义。
    init(device: AVCaptureDevice, photoOutput: AVCapturePhotoOutput, lens: LensType) {
        let format = device.activeFormat
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let maxFrameRate = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30

        #if os(iOS)
        let isoRange = format.minISO...format.maxISO
        let shutterRange = format.minExposureDuration...format.maxExposureDuration
        let evRange = device.minExposureTargetBias...device.maxExposureTargetBias
        let maxGain = device.maxWhiteBalanceGain
        let supportsProRAW = photoOutput.isAppleProRAWSupported
        let maxZoomFactor = format.videoMaxZoomFactor
        #else
        let isoRange: ClosedRange<Float> = 50...3200
        let shutterRange: ClosedRange<CMTime> = CMTime(value: 1, timescale: 8000)...CMTime(value: 1, timescale: 4)
        let evRange: ClosedRange<Float> = -2...2
        let maxGain: Float = 4.0
        let supportsProRAW = false
        let maxZoomFactor: CGFloat = 1.0
        #endif

        self.init(
            lens: lens,
            isoRange: isoRange,
            shutterRange: shutterRange,
            evRange: evRange,
            wbGainsRange: WBGainsRange(redRange: 1...maxGain, greenRange: 1...maxGain, blueRange: 1...maxGain),
            supportsRAW: !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty,
            supportsProRAW: supportsProRAW,
            maxZoomFactor: maxZoomFactor,
            supportedFormats: [CaptureFormatDescriptor(dimensions: dimensions, maxFrameRate: maxFrameRate)]
        )
    }
}

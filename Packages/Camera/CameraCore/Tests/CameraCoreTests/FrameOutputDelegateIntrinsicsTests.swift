import CoreMedia
import CoreVideo
import Testing
import simd

@testable import CameraCore

private func makeTestSampleBuffer() throws -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    let buffer = try #require(pixelBuffer)

    var formatDescription: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &formatDescription
    )
    let format = try #require(formatDescription)

    var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
    var sampleBuffer: CMSampleBuffer?
    let status = CMSampleBufferCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: buffer,
        dataReady: true,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: format,
        sampleTiming: &timingInfo,
        sampleBufferOut: &sampleBuffer
    )
    #expect(status == noErr)
    return try #require(sampleBuffer)
}

@Suite("FrameOutputDelegate.intrinsics(from:)")
struct FrameOutputDelegateIntrinsicsTests {

    @Test("extracts a matrix_float3x3 from the CameraIntrinsicMatrix attachment when present")
    func extractsIntrinsicsWhenAttachmentPresent() throws {
        let sampleBuffer = try makeTestSampleBuffer()
        // 一个真实相机内参矩阵的典型形状：焦距在 (0,0)/(1,1)，主点在第三列。
        let matrix = matrix_float3x3(
            SIMD3<Float>(1000, 0, 0),
            SIMD3<Float>(0, 1000, 0),
            SIMD3<Float>(960, 540, 1)
        )
        let data = withUnsafeBytes(of: matrix) { Data($0) }
        CMSetAttachment(
            sampleBuffer,
            key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
            value: data as CFData,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )

        let extracted = FrameOutputDelegate.intrinsics(from: sampleBuffer)

        #expect(extracted?.columns.0.x == 1000)
        #expect(extracted?.columns.1.y == 1000)
        #expect(extracted?.columns.2.x == 960)
        #expect(extracted?.columns.2.y == 540)
    }

    @Test("returns nil when the attachment is absent (intrinsic delivery not enabled/supported)")
    func returnsNilWhenAttachmentAbsent() throws {
        let sampleBuffer = try makeTestSampleBuffer()

        #expect(FrameOutputDelegate.intrinsics(from: sampleBuffer) == nil)
    }
}

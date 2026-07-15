import Testing

@testable import CameraCore
import Shared

@Suite("FramePlaybackProvider")
struct FramePlaybackProviderTests {

    @Test("lifecycle calls succeed without a real capture session")
    func lifecycleDoesNotThrow() async throws {
        let provider = FramePlaybackProvider(recordedFrames: [])

        try await provider.startRunning()
        try await provider.configureOutputs()
        await provider.stopRunning()
    }
}

@Suite("CameraSession")
struct CameraSessionTests {

    @Test("apply(.switchLens) updates the session without throwing on iOS")
    func switchLensDoesNotThrow() async throws {
        let session = CameraSession()

        // 手动镜头/曝光控制这套 AVFoundation API 整体是 iOS-only（见 CameraSession.apply 的
        // #if os(iOS) 分支）：真机/iOS 模拟器上应该真的切换镜头成功；在 swift test 跑在的
        // macOS host 上，这套 API 从设计上就不支持，预期是优雅地抛 CameraError，而不是崩溃。
        #if os(iOS)
        try await session.apply(.switchLens(.ultraWide))
        #else
        await #expect(throws: CameraError.self) {
            try await session.apply(.switchLens(.ultraWide))
        }
        #endif
    }

    @Test("capturePhoto without configured outputs surfaces CameraError")
    func capturePhotoFailsBeforeConfiguration() async {
        let session = CameraSession()

        await #expect(throws: CameraError.self) {
            _ = try await session.capturePhoto(PhotoCaptureRequest())
        }
    }
}

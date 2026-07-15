// AVCaptureSession/AVCaptureDevice 大量类型未标注 Sendable，@preconcurrency 让编译器把
// 跨 actor 边界传递这些类型当作"未审计、由调用方负责"处理，而不是当成硬错误拦下来
// （做法与 CameraPipeline.PipelineController 处理 Metal 类型一致）。
@preconcurrency import AVFoundation
import Shared

/// AVCaptureSession 生命周期，专用 sessionQueue，对外暴露为 actor。
public actor CameraSession: CaptureSessionProviding, CameraSourceProtocol {

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.myecoapp.camera.session")
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    private var currentLens: LensType = .wide
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var notificationObservers: [NSObjectProtocol] = []
    private var activePhotoDelegates: [DualTrackPhotoCaptureDelegate] = []

    // capability/interruption 的 continuation 只在本 actor 内部（apply/中断回调）产出新值，
    // 保持普通 actor-isolated 存储；frame 的 continuation 需要被 sessionQueue 上的
    // FrameOutputDelegate 直接调用，声明为 nonisolated（AsyncStream.Continuation 本身
    // 是无条件 Sendable，用于跨隔离域喂值正是它的设计目的，不需要 unsafe）。
    private let capabilityContinuation: AsyncStream<DeviceCapability>.Continuation
    private let interruptionContinuation: AsyncStream<InterruptionEvent>.Continuation
    private nonisolated let frameContinuation: AsyncStream<Frame>.Continuation

    // previewLayer 是 CALayer 的子类，AVFoundation 没有让它遵循 Sendable，但它在 init 里赋值一次后
    // 永不再变——用 nonisolated(unsafe) 声明为"确实不隔离"，否则 Swift 6 严格并发下，即便 await 读取，
    // 非 Sendable 值也不允许"逃出"actor 隔离域（真实报错："cannot exit actor-isolated context"）。
    public nonisolated(unsafe) let previewLayer: AVCaptureVideoPreviewLayer

    public nonisolated let frames: AsyncStream<Frame>
    public nonisolated let capability: AsyncStream<DeviceCapability>
    public nonisolated let interruptions: AsyncStream<InterruptionEvent>

    public init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)

        var frameContinuation: AsyncStream<Frame>.Continuation!
        frames = AsyncStream { frameContinuation = $0 }
        var capabilityContinuation: AsyncStream<DeviceCapability>.Continuation!
        capability = AsyncStream { capabilityContinuation = $0 }
        var interruptionContinuation: AsyncStream<InterruptionEvent>.Continuation!
        interruptions = AsyncStream { interruptionContinuation = $0 }

        self.frameContinuation = frameContinuation
        self.capabilityContinuation = capabilityContinuation
        self.interruptionContinuation = interruptionContinuation
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: CaptureSessionProviding

    public func startRunning() async throws {
        CameraLog.session.info("startRunning")

        try await requestPermissionIfNeeded()

        if session.inputs.isEmpty {
            try await configureOutputs()
        }
        observeSessionNotifications()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                session.startRunning()
                continuation.resume()
            }
        }
    }

    public func stopRunning() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                session.stopRunning()
                continuation.resume()
            }
        }
    }

    public func configureOutputs() async throws {
        guard let device = Self.discoverDevice(for: currentLens) else {
            throw CameraError.deviceUnavailable(currentLens)
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        do {
            try attachInput(for: device)
        } catch {
            session.commitConfiguration()
            throw error
        }

        if session.canAddOutput(videoDataOutput) {
            // 显式指定 BGRA：CameraFeature 的 CameraPipelineBridge 用 CVMetalTextureCache 零拷贝
            // 转 MTLTexture 时按 .bgra8Unorm 建纹理，要求源 CVPixelBuffer 就是这个像素格式——
            // 不设置的话默认是设备原生格式（通常是 YCbCr 双平面），无法直接建单平面 BGRA 纹理。
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            let delegate = FrameOutputDelegate(continuation: frameContinuation)
            videoDataOutput.setSampleBufferDelegate(delegate, queue: sessionQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoDataOutput)
            // isCameraIntrinsicMatrixDeliveryEnabled 必须在 addOutput 之后设置（connection 只有
            // 加完 output 才存在）；相机内参矩阵是 iOS-only 能力（Mac 摄像头没有对应概念），
            // 不支持时 FrameOutputDelegate 读 attachment 会正常拿到 nil，不影响其余帧数据。
            #if os(iOS)
            if let connection = videoDataOutput.connection(with: .video),
               connection.isCameraIntrinsicMatrixDeliverySupported {
                connection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
            #endif
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            #if os(iOS)
            photoOutput.maxPhotoQualityPrioritization = .quality
            #endif
        }
        session.commitConfiguration()

        currentDevice = device
        publishCapability(for: device)
    }

    // MARK: CameraSourceProtocol

    public func apply(_ control: CameraControl) async throws {
        // 手动曝光/白平衡/变焦这套 API 在 AVFoundation 里整体是 iOS-only（Mac 摄像头没有对应的
        // 手动控制能力），macOS host 上统一退回 unsupportedControl，保持本包可 swift build。
        #if os(iOS)
        switch control {
        case .switchLens(let lens):
            try await switchLens(to: lens)
        case .setISO(let iso):
            try withLockedDevice { device in
                device.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: iso, completionHandler: nil)
            }
        case .setShutter(let duration):
            try withLockedDevice { device in
                device.setExposureModeCustom(duration: duration, iso: AVCaptureDevice.currentISO, completionHandler: nil)
            }
        case .setExposureBias(let bias):
            try withLockedDevice { device in
                device.setExposureTargetBias(bias, completionHandler: nil)
            }
        case .setWhiteBalance(let gains):
            try withLockedDevice { device in
                guard device.isLockingWhiteBalanceWithCustomDeviceGainsSupported else {
                    throw CameraError.unsupportedControl("setWhiteBalance")
                }
                let maxGain = device.maxWhiteBalanceGain
                let clamped = AVCaptureDevice.WhiteBalanceGains(
                    redGain: min(max(gains.red, 1), maxGain),
                    greenGain: min(max(gains.green, 1), maxGain),
                    blueGain: min(max(gains.blue, 1), maxGain)
                )
                device.setWhiteBalanceModeLocked(with: clamped, completionHandler: nil)
            }
        case .focus(let point):
            try withLockedDevice { device in
                guard device.isFocusPointOfInterestSupported else {
                    throw CameraError.unsupportedControl("focus")
                }
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
        case .setZoom(let factor):
            try withLockedDevice { device in
                let range = device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor
                device.videoZoomFactor = min(max(factor, range.lowerBound), range.upperBound)
            }
        case .setTorch(let isOn):
            try withLockedDevice { device in
                guard device.hasTorch else {
                    throw CameraError.unsupportedControl("torch")
                }
                device.torchMode = isOn ? .on : .off
            }
        }
        #else
        throw CameraError.unsupportedControl("\(control)")
        #endif
    }

    public func capturePhoto(_ request: PhotoCaptureRequest) async throws -> PhotoCaptureResult {
        try await captureDualTrack(request)
    }

    // iso/exposureDuration/lensPosition 是瞬时可读属性（不需要 lockForConfiguration），
    // 但整体是 iOS-only API（Mac 摄像头没有对应能力），macOS host 上退回全零快照。
    public func currentExposureMetadata() -> CaptureExposureMetadata {
        #if os(iOS)
        guard let currentDevice else {
            return CaptureExposureMetadata(iso: 0, shutterDuration: .zero, lensPosition: 0)
        }
        return CaptureExposureMetadata(
            iso: currentDevice.iso,
            shutterDuration: currentDevice.exposureDuration,
            lensPosition: currentDevice.lensPosition
        )
        #else
        return CaptureExposureMetadata(iso: 0, shutterDuration: .zero, lensPosition: 0)
        #endif
    }

    // MARK: 镜头切换

    #if os(iOS)
    private func switchLens(to lens: LensType) async throws {
        guard let device = Self.discoverDevice(for: lens) else {
            throw CameraError.deviceUnavailable(lens)
        }
        session.beginConfiguration()
        do {
            try attachInput(for: device)
        } catch {
            session.commitConfiguration()
            throw error
        }
        session.commitConfiguration()

        currentLens = lens
        currentDevice = device
        publishCapability(for: device)
    }
    #endif

    private func attachInput(for device: AVCaptureDevice) throws {
        if let currentInput {
            session.removeInput(currentInput)
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.sessionConfigurationFailed(underlying: error)
        }
        guard session.canAddInput(input) else {
            throw CameraError.sessionConfigurationFailed(underlying: nil)
        }
        session.addInput(input)
        currentInput = input
    }

    private func publishCapability(for device: AVCaptureDevice) {
        let capability = DeviceCapability(device: device, photoOutput: photoOutput, lens: currentLens)
        capabilityContinuation.yield(capability)
    }

    /// AVCaptureDevice 的手动控制统一通过 lockForConfiguration 包一层，出错转换成 CameraError。
    private func withLockedDevice(_ body: (AVCaptureDevice) throws -> Void) throws {
        guard let device = currentDevice else {
            throw CameraError.deviceUnavailable(currentLens)
        }
        do {
            try device.lockForConfiguration()
        } catch {
            throw CameraError.sessionConfigurationFailed(underlying: error)
        }
        defer { device.unlockForConfiguration() }
        try body(device)
    }

    // builtInUltraWideCamera / builtInTelephotoCamera 是 iOS-only 设备类型（Mac 摄像头没有
    // 多镜头概念），macOS host 上只能退回 builtInWideAngleCamera，用于让本包保持可 swift build。
    private static func discoverDevice(for lens: LensType) -> AVCaptureDevice? {
        #if os(iOS)
        let deviceType: AVCaptureDevice.DeviceType
        switch lens {
        case .wide: deviceType = .builtInWideAngleCamera
        case .ultraWide: deviceType = .builtInUltraWideCamera
        case .tele: deviceType = .builtInTelephotoCamera
        }
        #else
        let deviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
        #endif
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [deviceType], mediaType: .video, position: .back
        ).devices.first
    }

    private func requestPermissionIfNeeded() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw CameraError.permissionDenied }
        case .denied, .restricted:
            throw CameraError.permissionDenied
        @unknown default:
            throw CameraError.permissionDenied
        }
    }

    // MARK: 中断与恢复

    /// 监听 AVCaptureSession.wasInterrupted / interruptionEnded / runtimeError 通知，
    /// 把事件转成 InterruptionEvent 向上抛出；具体的恢复策略（例如自动重新 start()）
    /// 由 L4 CameraSessionUseCase 订阅 interruptions 决定，本类只负责事件产出。
    private func observeSessionNotifications() {
        guard notificationObservers.isEmpty else { return }

        let center = NotificationCenter.default
        // 通知回调本身是 @Sendable 闭包，不能直接捕获 session/sessionQueue 这类非 Sendable 的
        // AVFoundation 对象；统一用 [weak self] + Task 跳回 actor，在 actor-isolated 方法里处理。
        let began = center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] notification in
            let reason = Self.interruptionReason(from: notification)
            Task { await self?.publishInterruption(.began(reason: reason)) }
        }
        let ended = center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            Task { await self?.publishInterruption(.ended) }
        }
        let runtimeError = center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] notification in
            let description = (notification.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.localizedDescription ?? "unknown"
            Task { await self?.handleRuntimeError(description: description) }
        }
        notificationObservers = [began, ended, runtimeError]
    }

    private func publishInterruption(_ event: InterruptionEvent) {
        interruptionContinuation.yield(event)
    }

    private func handleRuntimeError(description: String) async {
        interruptionContinuation.yield(.runtimeError(description))
        // AVCam 的标准做法：runtimeError 后尝试自动重启 session。
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                session.startRunning()
                continuation.resume()
            }
        }
    }

    // AVCaptureSessionInterruptionReasonKey / InterruptionReason 是 iOS-only API。
    private static func interruptionReason(from notification: Notification) -> String {
        #if os(iOS)
        let reasonValue = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue
        return reasonValue.flatMap(AVCaptureSession.InterruptionReason.init).map(String.init(describing:)) ?? "unknown"
        #else
        return "unknown"
        #endif
    }

    // MARK: 拍照委托生命周期（供 CapturePhoto+DualTrack.swift 使用）

    func retainPhotoDelegate(_ delegate: DualTrackPhotoCaptureDelegate) {
        activePhotoDelegates.append(delegate)
    }

    func releasePhotoDelegate(_ delegate: DualTrackPhotoCaptureDelegate) {
        activePhotoDelegates.removeAll { $0 === delegate }
    }

    var currentPhotoOutput: AVCapturePhotoOutput { photoOutput }
}

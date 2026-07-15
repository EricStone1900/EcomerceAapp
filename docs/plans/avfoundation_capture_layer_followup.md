# AVFoundation 真实采集链路补全（Stage 1-3 已知限制的后续修复）

> Stage 1/2/3 的 `CameraSession`（`CameraCore`）在架构骨架阶段一直是占位实现——`startRunning`/`configureOutputs`/`apply`/`capturePhoto` 都只有注释、没有真正调用 AVFoundation。三份 stage 计划文档的"已知限制"里反复提到这一点。本文档记录把 `CameraSession` 补成真实实现的过程，以及过程中发现的若干与平台可用性、Swift 6 并发相关的坑。

## 背景

用户在 Stage 3 完成后要求"先把真实的 AVFoundation 采集层填上"，再继续 Stage 4。这不是任何一份 stage 计划文档里列出的任务，而是把此前一直标记为"占位/已知限制"的部分真正实现掉。范围限定在 `CameraCore`（L1 采集层）——不包括把真实帧接入 `PipelineController`（那需要 `CameraFeature` 里做 `CameraCore.Frame → CameraPipeline.Frame` 的转换，本轮没有做，见下方"仍未完成的部分"）。

## 做了什么

### 1. `CameraSourceProtocol` 新增中断事件流（`CameraCore/Protocol/CameraSourceProtocol.swift`）

```swift
public enum InterruptionEvent: Sendable, Equatable {
    case began(reason: String)
    case ended
    case runtimeError(String)
}

public protocol CameraSourceProtocol: Actor {
    ...
    var interruptions: AsyncStream<InterruptionEvent> { get }
    ...
}
```

Stage 1 的 `CameraSessionUseCase.handleInterruption(ended:reason:)` 只能被手动调用（测试直接调），没有真实的中断通知会触发它。加这个协议要求之后，`CameraSession` 把 AVFoundation 的中断/恢复/运行时错误通知转成事件往外推，`CameraSessionUseCase` 在 `start()` 第一次调用时订阅这个流，自动驱动状态机——不再需要任何人手动转发通知。

### 2. `CameraSession` 真实实现（`CameraCore/CameraSession.swift`）

- `startRunning()`：`AVCaptureDevice.authorizationStatus`/`requestAccess` 权限检查 → 首次调用时 `configureOutputs()` → 在专用 `sessionQueue` 上调用 `session.startRunning()`。
- `configureOutputs()`：`AVCaptureDevice.DiscoverySession` 发现镜头设备 → `AVCaptureDeviceInput` 接入 → 添加 `AVCaptureVideoDataOutput`（真实帧产出）+ `AVCapturePhotoOutput`（真实拍照）→ 发布 `DeviceCapability`。
- `apply(_:)`：`.switchLens` 重新发现设备并替换 input；`.setISO`/`.setShutter` 通过 `setExposureModeCustom(duration:iso:)`（配合 `AVCaptureDevice.currentISO`/`currentExposureDuration` 哨兵值表示"保持当前值"）；`.setExposureBias`/`.setWhiteBalance`/`.focus`/`.setZoom`/`.setTorch` 各自映射到对应的 `AVCaptureDevice` API，统一走 `lockForConfiguration()`。
- 会话中断/恢复：`NotificationCenter` 监听 `wasInterruptedNotification`/`interruptionEndedNotification`/`runtimeErrorNotification`，转成 `InterruptionEvent` 推给 `interruptions` 流；`runtimeError` 额外触发自动重启（AVCam 范例的标准做法）。

### 3. 真实帧产出（新文件 `CameraCore/FrameOutputDelegate.swift`）

`AVCaptureVideoDataOutputSampleBufferDelegate` 的独立类，把 `CMSampleBuffer` 转成 `CameraCore.Frame`（只有 pixelBuffer + timestamp，不含 orientation/metadata——那些字段属于 `CameraPipeline.Frame`，见下方"仍未完成的部分"）后 `yield` 给 `frameContinuation`。

### 4. 真实 RAW+HEIF 双轨拍照（新文件 `CameraCore/DualTrackPhotoCaptureDelegate.swift`，修改 `CapturePhoto+DualTrack.swift`）

`AVCapturePhotoCaptureDelegate` 委托类，`didFinishProcessingPhoto` 按 `photo.isRawPhoto` 分流写盘为 DNG/HEIC（`AVCapturePhoto.fileDataRepresentation()` 自动带上系统采集到的 EXIF/GPS 元数据，不需要手动拼字典），`didFinishCaptureFor` 是终点，resume 一个 `CheckedContinuation`。`CameraSession.capturePhoto(_:)` 现在真正委托给 `captureDualTrack(_:)`（Stage 1/2 时只是 throw 一个占位错误）。

### 5. 真实设备能力查询（新文件 `CameraCore/DeviceCapability+AVCaptureDevice.swift`）

`DeviceCapability(device:photoOutput:lens:)`：从 `AVCaptureDevice.activeFormat` 读 ISO/快门/变焦范围，`AVCapturePhotoOutput` 读 RAW/ProRAW 支持情况。

## 过程中发现的坑

### AVFoundation 相机控制 API 大面积是 iOS-only

这是本轮最大的意外发现：不只是"多镜头发现"（`builtInUltraWideCamera`/`builtInTelephotoCamera`），连**手动曝光**（`setExposureModeCustom`/`setExposureTargetBias`）、**手动白平衡**（`setWhiteBalanceModeLocked`/`maxWhiteBalanceGain`）、**变焦**（`videoZoomFactor`/`min/maxAvailableVideoZoomFactor`）、**能力查询**（`minISO`/`maxISO`/`minExposureDuration`/`maxExposureDuration`/`minExposureTargetBias`/`maxExposureTargetBias`/`videoMaxZoomFactor`/`isAppleProRAWSupported`）、**中断原因解析**（`AVCaptureSessionInterruptionReasonKey`/`AVCaptureSession.InterruptionReason`）、**RAW 拍照设置**（`AVCapturePhotoSettings(rawPixelFormatType:processedFormat:)`）、**RAW/Processed 区分**（`AVCapturePhoto.isRawPhoto`）全部是 `API_UNAVAILABLE(macos)`。Mac 摄像头压根没有这套手动控制能力的公开接口。

处理方式：在 `CameraCore` 里用 `#if os(iOS) ... #else ... #endif` 分支包住每一处，macOS 分支要么退回保守默认值（`DeviceCapability` 的 ISO/快门/EV 范围），要么直接 `throw CameraError.unsupportedControl(...)`（`apply(_:)` 的整个 switch）。这不是为了让 macOS 上"能用"——这个 App 从来不打算跑在 macOS 上——纯粹是为了保住 `swift build`/`swift test` 能在本机 CLI 跑，不需要每次改 `CameraCore` 都得开 Xcode 用 iOS 模拟器验证。真实行为只在 iOS 上生效。

### `capturePhoto` 在没有 video connection 时会让进程崩溃，不是抛 Swift 错误

`AVCapturePhotoOutput.capturePhoto(with:delegate:)` 在没有已启用的 video connection 时抛的是 **Objective-C 异常**（`NSGenericException`），Swift 的 `try`/`catch` 接不住，直接让整个测试进程崩溃退出（signal 6）。这是在跑单测时才发现的真实 bug——`CameraSessionCapabilityTests.swift` 里"未配置直接拍照应该抛 CameraError"这条测试原本就存在（Stage 1 就写了），但 Stage 1 的 `capturePhoto` 是纯占位实现（直接 throw），从来没有真的调用到 `AVCapturePhotoOutput`，所以这个崩溃一直没暴露，直到这轮接上真实实现才炸出来。修复：`captureDualTrack` 调用前先用 `photoOutput.connection(with: .video) != nil` 判断，没有 connection 直接 throw 可捕获的 `CameraError`。

### Swift 6 严格并发：与 Stage 1/2 同类问题的新变体

- `previewLayer`/`renderedFrames` 已经用过的 `nonisolated(unsafe)` 模式，这次在 `frameContinuation`（`AsyncStream<Frame>.Continuation` 本身无条件 Sendable，不需要 unsafe，直接 `nonisolated let` 即可）上又用了一次——两种情况的判断依据是"这个类型本身是否真的 Sendable"，continuation 是，`AVCaptureVideoPreviewLayer`/`MTLTexture` 不是。
- `NotificationCenter` 的观察闭包是 `@Sendable` 的，不能直接捕获 `session`（非 Sendable）——统一改成 `[weak self]` + `Task { await self?.xxx(...) }` 跳回 actor 处理，闭包本身只提取 Sendable 的基本类型（`String`）后就不再持有 AVFoundation 对象。
- `DualTrackPhotoCaptureDelegate` 的 `onFinished` 回调原本想用"提前声明一个 `var delegate` 再在闭包里捕获它自己"的写法（常见于 Objective-C/旧 Swift 代码），在 Swift 6 下会报 `capture of 'delegate' with non-Sendable type ... in an isolated closure`——改成 `onFinished` 把 `self` 当参数传回去（`(DualTrackPhotoCaptureDelegate) -> Void`），delegate 自己在回调里传 `self`，不再需要外部的自引用捕获。这个委托类最终整体标了 `@unchecked Sendable`：`AVCapturePhotoOutput` 保证同一次拍照的所有委托回调都在同一个串行队列上顺序发生，不存在真实的并发写入，只是类型系统看不出来。
- `CameraSourceProtocol`/`CaptureSessionProviding` 都是 `: Actor`，通过存在类型（`any CameraSourceProtocol`）访问一个属性时，即使具体类型（`CameraSession`）把它实现成 `nonisolated`，**协议声明的隔离级别仍然要求 `await`**——`CameraSessionUseCase` 订阅 `cameraSource.interruptions` 时踩到了这个，要先 `let stream = await cameraSource.interruptions` 再 `for await`。
- 在 actor 的 `init` 里创建一个弱引用 `self` 的 `Task` 并把结果存进 `self` 的另一个属性，会报 `cannot access property here in nonisolated initializer`——actor 的 `init` 阶段 `self` 还没有真正"进入"隔离域，一旦闭包捕获了 `[weak self]`，编译器就不再允许在同一个 `init` 里继续做属性赋值。修复：把这段订阅逻辑挪到 `start()`（一个正常的 actor-isolated 方法）里，用一个"是否已订阅"的哨兵变量保证只订阅一次。

### `CameraSessionUseCase` 需要访问 `CaptureSessionProviding`，不能只依赖 `CameraSourceProtocol`

Stage 1 的 `CameraSessionUseCase.start()` 一直是用 `cameraSource.apply(.setZoom(1.0))` 当"触发一次 session 配置校验"的替代品——因为它当时只持有 `any CameraSourceProtocol`，这个协议没有 `startRunning()`。这次把 `apply()` 的桩实现换成真实的 AVFoundation 调用后，这个替代品显然是不对的：切换镜头/设焦距根本不等于启动会话。修正：把 `CameraSessionUseCase` 的存储类型改成 `any CameraSourceProtocol & CaptureSessionProviding`（组合类型，不是新建一个合并协议——`FramePlaybackProvider` 故意只实现 `CaptureSessionProviding`，不应该被强迫实现整个 `CameraSourceProtocol`），`start()` 现在真正调用 `cameraSource.startRunning()`。

## 验证方式

```bash
cd Packages/Camera/Shared && swift test          # 9/9
cd Packages/Camera/CameraCore && swift test       # 3/3（含新增的崩溃修复回归测试）
cd Packages/Camera/CameraPipeline && swift test   # 4/4
cd Packages/Camera/CameraVision && swift test     # 9/9
cd Packages/Camera/CameraFeature && swift test    # 7/7（新增：真实中断事件流驱动状态机的端到端测试）
```

`CameraSessionCapabilityTests.swift` 里 `apply(.switchLens)` 那条测试现在用 `#if os(iOS)` 区分两种预期：iOS 上应该真的切换成功，`swift test` 实际跑在的 macOS host 上应该优雅地抛 `CameraError`（因为手动镜头控制在 macOS 上本来就不支持）——两边都不是"跳过测试"，而是各自平台上真实、正确的行为。

`CameraFeatureTests` 新增的 `interruptionStreamDrivesStateAutomatically` 测试了完整链路：`useCase.start()` → mock 源触发 `.began` → 状态变 `.interrupted` → mock 源触发 `.ended` → 状态自动变回 `.running` 且 `startRunning()` 被自动调用了第二次——这是纯逻辑验证（mock 源，不接真机），证明订阅-恢复这条链路本身是对的；真机上来电中断能否真的恢复，仍然需要人工测试。

`CameraUI` 依旧无法用 `swift build` 验证（原因见 Stage 1/2/3 文档），本轮没有改动 `CameraUI` 的任何文件。

## 仍未完成的部分

1. ~~**`CameraCore.Frame` 从未真正流到 `CameraPipeline`**~~ ——已在 [`frame_bridging_followup.md`](./frame_bridging_followup.md) 里实现（`CameraFeature.CameraPipelineBridge`）。
2. Stage 1 验收清单里"手动参数在锁屏-解锁后保持"——`CameraSessionUseCase.handle(.ended)` 会自动重新 `start()`，但不会重放上一次的手动 ISO/快门/EV/WB 设置（这些从来没有被记忆下来）。文档里当初设计成"重放逻辑属于更上层（UI/Preset）职责"，Stage 4 的 `PresetUseCase` 出现之前，这条验收项实际上无人负责。
3. `configureOutputs()` 目前每次都是"发现镜头 → 接入 input → 加两个 output"，没有处理"session 已经在跑的时候重新配置"的情况（`beginConfiguration`/`commitConfiguration` 期间画面会短暂黑屏，这是 AVFoundation 的固有行为，不是 bug，但没有做任何优化，比如切镜头时保留 output 只换 input 的分支已经有，但没有验证过实际切换的流畅度）。
4. 本轮没有触碰 `MyEcommerce/Debug/CameraDebugView.swift` 之外的任何 App 层代码，也没有让用户在 Xcode 里重新验证过——**这轮改动全部通过 CLI `swift build`/`swift test` 验证，真机行为（权限弹窗、真实镜头切换、来电中断恢复、RAW+HEIF 落盘）都还需要用户在 Xcode 里用真机/模拟器跑一遍**。

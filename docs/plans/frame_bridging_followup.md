# Frame Bridging Followup：CameraCore.Frame → CameraPipeline.Frame

> 补上 `avfoundation_capture_layer_followup.md`"仍未完成的部分"第 1 条：把真实摄像头帧接入 `PipelineController`，让 Histogram/Vision 检测这些依赖 Pipeline 的功能第一次收到真实数据。

## 背景

`avfoundation_capture_layer_followup.md` 把 AVFoundation 采集层填成真实实现后，`CameraDebugView` 的 Passthrough 预览已经能显示真实画面，但那条链路是 `session.previewLayer` 直连 `AVCaptureSession`，完全绕开了 `CameraPipeline`。`FrameOutputDelegate` 产出的 `CameraCore.Frame`（只有 `pixelBuffer` + `timestamp`）从来没有转换成 `PipelineController.consume(_:texture:context:)` 需要的 `CameraPipeline.Frame`（多 `orientation`/`cameraMetadata`）+ `MTLTexture`，所以 Histogram 分析器、Vision 文档检测这些 Stage 2/3 已经写好的代码实际上从未收到过一帧真实数据。

## 新增内容

### 1. `CameraCore.CaptureExposureMetadata`（新文件）

L1 对外暴露的曝光快照，只含 `iso` / `shutterDuration` / `lensPosition` 三个瞬时可读的 `AVCaptureDevice` 属性。加进 `CameraSourceProtocol` 作为新的协议要求 `func currentExposureMetadata() -> CaptureExposureMetadata`，`CameraSession` 里的实现直接读 actor-isolated 的 `currentDevice`（不需要额外加锁，因为已经在 actor 隔离域内），iOS-only（`#if os(iOS)`，macOS host 退回全零快照，跟包里其它设备控制 API 的处理方式一致）。

### 2. `videoDataOutput.videoSettings` 显式指定 BGRA

`CameraSession.configureOutputs()` 里给 `videoDataOutput` 加了 `kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA`。不设置的话默认是设备原生格式（通常是 YCbCr 双平面），`CVMetalTextureCache` 没法直接从那种格式建单平面纹理。

### 3. `CameraFeature.CameraPipelineBridge`（新 actor，新文件 `CameraFeature/Sources/CameraFeature/Bridge/CameraPipelineBridge.swift`）

真正做转换的地方，放在 L4 CameraFeature（同时依赖 CameraCore 和 CameraPipeline，是唯一能同时看见两个 `Frame` 类型的层）：

- 持有 `MTLDevice` / `MTLCommandQueue` / `CVMetalTextureCache`（`CVMetalTextureCacheCreate` 建一次，复用）
- `start()` 订阅 `cameraSource.frames`，每一帧：
  - `CVMetalTextureCacheCreateTextureFromImage` 零拷贝转 `MTLTexture`（`.bgra8Unorm`）
  - `await cameraSource.currentExposureMetadata()` 拿真实 iso/shutter/lensPosition
  - 拼出 `CameraPipeline.Frame` + `RenderContext`（每帧新建一个 `MTLCommandBuffer`）
  - `await pipelineController.consume(frame, texture:, context:)`，然后 `commandBuffer.commit()`
- `stop()` 取消订阅 Task；`start()` 幂等（已有订阅时直接返回）

### 已知简化（不是伪造数据，是明确推迟的范围）

- **`orientation` 固定为 `.right`**：后置摄像头 + 竖屏持机的常见默认值。真正的设备朝向跟踪需要 `UIDevice.orientation` 或 `CMMotionManager`，是独立的功能，本轮没做。
- **`cameraMetadata.intrinsics` 固定为 `nil`**：相机内参矩阵需要开 `AVCaptureConnection.isCameraIntrinsicMatrixDeliveryEnabled` 并在 `FrameOutputDelegate` 里读 `CMSampleBuffer` 的 `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix` attachment——`FrameMetadata.intrinsics` 本来就是 Optional，按需推迟不算偷工减料。
- **`iso` / `shutterDuration` / `lensPosition` 是真实值**，不是占位符。

## 过程中发现的坑

**`CVMetalTextureCache` 要求 IOSurface-backed 的 `CVPixelBuffer`，测试写挂过一次。** 第一版 `CameraPipelineBridgeTests` 用 `CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)` 造测试用的假帧——`nil` attributes 意味着不带 IOSurface 属性。真机摄像头输出的 buffer 本来就是 IOSurface-backed，不受影响；但手工 `CVPixelBufferCreate` 默认不是，`CVMetalTextureCacheCreateTextureFromImage` 对着非 IOSurface buffer 会静默返回失败状态（不抛错、不崩溃），`makeTexture` 拿到 `nil` 直接 `guard` 丢帧，测试卡在 `await iterator.next()` 上——`swift test` 进程真实挂起，用 `ps aux` 确认进程还在跑之后才定位到。修法：显式传 `[kCVPixelBufferIOSurfacePropertiesKey: [:]]`。

## 验证结果

```
=== Shared ===        Build complete!  9 tests passed
=== CameraCore ===    Build complete!  3 tests passed
=== CameraPipeline === Build complete! 4 tests passed
=== CameraVision ===  Build complete!  9 tests passed
=== CameraFeature === Build complete!  9 tests passed（含新增的 2 条 CameraPipelineBridge 测试）
```

`CameraPipelineBridgeTests` 里两条新测试都用真实 `CVMetalTextureCache` 转换（不是 mock），验证了：一个真实 `CVPixelBuffer` 能完整流过 bridge、进 `PipelineController.consume`、从 `renderedFrames` 流出来一个尺寸/像素格式都对的 `MTLTexture`；以及 `start()` 重复调用不会重复订阅。

## App 层接入（第二轮：`CameraDebugView`）

用户看到黑屏问题解决、Frame bridging 落地后，紧接着要求把它接进调试页，才能真的用肉眼验收"Pipeline 收到了真实帧"这件事。改动：

- **`CameraDebugViewModel`** 新增 `pipelineController: PipelineController` + `bridge: CameraPipelineBridge?`，`start()` 里在 `sessionUseCase.start()` 之后，挂 `HistogramAnalyzer()` 到 `pipelineController.setAnalyzers(...)`，创建并 `start()` 一个 `CameraPipelineBridge(cameraSource: session, pipelineController: pipelineController)`；再订阅 `pipelineController.annotations` 把收到的 annotation 数量发布成 `@Published var annotationCount`，作为"分析链真的在跑"的肉眼可见证据（histogram 具体数值本身还是 Stage 2 遗留的占位实现，见下方"仍未完成的部分"）。
- **`CameraDebugView`** 新增一个 `Picker` 在 `PreviewMode.passthrough` / `.processed` 之间切换，`.processed` 分支渲染 `ProcessedPreviewContainer(renderedFrames: viewModel.renderedFrames)`。
- **`CameraUI.ProcessedPreviewContainer`** 把 Stage 2 遗留的渲染占位（`_ = view; _ = texture`，什么都不画）换成真实实现：`MTKView` 关掉自带的定时 `draw()`（`isPaused = true` / `enableSetNeedsDisplay = false`），改成 `renderedFrames` 每到一帧就手动渲染一次；用 `CIContext.render(_:to:commandBuffer:bounds:colorSpace:)` 把 `MTLTexture` 直接 GPU 侧写进 `drawable.texture`（`framebufferOnly` 需要设成 `false` 才能这样写），再 `commandBuffer.present(drawable)` + `commit()`。选 `CIContext` 而不是手写 MSL vertex/fragment shader：效果一样是纯 GPU 路径（不是"内存铁律"禁止的 CPU 侧 CIImage↔UIImage 往返，那条规则针对的是分析链对 CVPixelBuffer 的处理，不是最终把已转换好的纹理呈现到屏幕这一步），但不用在 `CameraUI` 这个完全没法 CLI 验证的包里管理 `.metal` shader 编译 + `makeDefaultLibrary(bundle:)` 这条出错面更大的路径。

**已知简化**：`CIImage(mtlTexture:).oriented(.downMirrored)` 是按"MTLTexture 行序 origin 左上、CIImage 默认坐标系 origin 左下，两者相反"这条通用规律写的翻转，没有真机验证过——如果真机上 Processed 预览画面上下颠倒或镜像错了，把 `.downMirrored` 换成 `.up`/`.upMirrored`/`.down` 之一即可，问题只在这一行。

## 真实直方图统计（第三轮：`HistogramAnalyzer` + `OverlayCanvas`）

`Frame.pixelBuffer` 有了真实数据源之后，把上一轮标记为"已解锁但仍是占位"的两处补成真实实现：

- **`CameraPipeline.HistogramAnalyzer`**：用 `Accelerate`/`vImage` 替换空 bucket 占位。`vImageHistogramCalculation_ARGB8888` 对交错的 BGRA buffer 直接统计四个 channel（顺序按内存字节序是 B/G/R/A，不是按 API 名字面意义的 A/R/G/B）；luminance 不是拿 R/G/B 三条直方图加权平均凑出来的（那样在数学上不等于对像素先加权求亮度再统计分布），而是先用 `vImageMatrixMultiply_ARGB8888ToPlanar8`（定点权重 29/150/77/0，对应 B/G/R/A，标准 luma 系数 0.114/0.587/0.299/0）转出单通道亮度平面，再对这个平面单独跑 `vImageHistogramCalculation_Planar8`。256 个原始 bin 按 `bucketCount`（默认 32）分组求和，再按各自通道的最大值归一化到 `[0, 1]`，供 UI 直接用。像素格式不是 `kCVPixelFormatType_32BGRA`（理论上不会发生，因为 `CameraSession` 已经显式配置了这个格式，见上文）时返回空 bucket 而不是崩溃。
- **`CameraUI.OverlayCanvas`**：`case .histogram: break` 换成真实绘制——屏幕底部一个 80pt 高的半透明面板，四条曲线（luminance 用白色，R/G/B 用对应颜色，都是半透明），bucket 值已经在 `HistogramAnalyzer` 里归一化到 `[0, 1]`，这里只做线性映射到面板高度，不需要 UI 层再关心原始计数量级。新增 `import CameraPipeline`（`HistogramData` 定义在那里）。

**测试**：这轮没有只满足于"产出了一个 `.histogram` case"这种形状测试，额外造了纯色 BGRA 测试帧（`TestSupport.makeSolidColorFrame`，直接写像素字节，不经过任何采集或编解码路径）验证统计结果本身是对的——纯红帧应该在 `redBuckets` 最后一个 bucket 出现唯一峰值、`greenBuckets`/`blueBuckets` 在第一个 bucket 出现唯一峰值、`luminanceBuckets` 峰值既不在头也不在尾（纯红的 luma 既不是 0 也不是 255）；纯白帧应该四条曲线都在最后一个 bucket 出现峰值；再加一个不支持的像素格式（`kCVPixelFormatType_32ARGB`）返回全空 bucket 而不崩溃的边界测试。`CameraPipeline` 从 4 条测试涨到 7 条，全部通过。

```
=== Shared ===        9 tests passed
=== CameraCore ===    3 tests passed
=== CameraPipeline === 7 tests passed（新增 3 条：纯红/纯白/不支持格式）
=== CameraVision ===  9 tests passed
=== CameraFeature === 9 tests passed
```

## Overlay 接入（第四轮：`CameraDebugView` 叠加 `OverlayCanvas`）

紧接着把 `OverlayCanvas` 叠到预览画面上，让直方图曲线真的能在屏幕上看见，不然上一轮的统计实现无从肉眼验收。

- **`CameraDebugView.swift`** 新增私有 `PreviewLayerFrameProvider: CALayerFrameProviding`，只存一个 `CGRect` 快照而不是持有 `AVCaptureVideoPreviewLayer` 引用——`CALayerFrameProviding` 要求 `Sendable`，`AVCaptureVideoPreviewLayer` 是非 `Sendable` 的 UIKit 类，直接存引用在 Swift 6 严格并发检查下会编译失败；而 histogram 这个用例本来就不需要坐标转换（`OverlayManager.makeScreenAnnotations` 对 `.histogram` 是直接透传，不走 `CoordinateConverter.convert`），所以快照值是否随预览尺寸变化不影响这里要验收的东西。
- `CameraDebugViewModel.start()` 里用这个 provider 构造一次 `OverlayManager`，`observeAnnotationsIfNeeded()` 收到新 annotations 时用它转成 `[ScreenAnnotation]`，发布成新的 `@Published var screenAnnotations`。
- `CameraDebugView.body` 的 `ZStack` 里在预览层之上叠一层 `OverlayCanvas(annotations: viewModel.screenAnnotations, showsGrid: false, showsLevel: false)`——不受 Passthrough/Processed 切换影响，因为 `CameraPipelineBridge` 从 `start()` 起就在独立消费 `cameraSource.frames`，跟屏幕上显示哪个预览无关。

## 设备朝向跟踪（第五轮：`CameraPipelineBridge.currentOrientation()`）

上一轮 Xcode/真机验证通过后（Processed 预览、直方图曲线叠加都确认显示正常），继续补上"已知简化"里的第一项。

- **`CameraPipelineBridge`** 新增 `private func currentOrientation() async -> CGImagePropertyOrientation`：`#if os(iOS)` 下先（只做一次，用 actor 状态位 `hasStartedDeviceOrientationNotifications` 防重复）调用 `UIDevice.current.beginGeneratingDeviceOrientationNotifications()`（不调用这个的话 `.orientation` 恒为 `.unknown`），然后每帧 `await MainActor.run { UIDevice.current.orientation }` 读取当前值，按标准映射表转成 `CGImagePropertyOrientation`：`.portrait → .right`、`.portraitUpsideDown → .left`、`.landscapeLeft → .up`、`.landscapeRight → .down`，`faceUp`/`faceDown`/`unknown` 退回 `.right`。macOS host（CLI 验证用的平台）没有 `UIDevice`，`#else` 分支固定返回 `.right`，跟 `CameraSession.currentExposureMetadata()` 的 macOS 降级方式一致。
- **只覆盖后置摄像头场景，没有处理镜像**：`CameraSession` 的 `AVCaptureDevice.DiscoverySession` 目前硬编码 `position: .back`（`Packages/Camera/CameraCore/Sources/CameraCore/CameraSession.swift`），本项目还不支持前置摄像头，所以不需要额外的镜像转换逻辑——如果以后加前置摄像头支持，这里的映射表要重新推导。
- 每帧调用一次 `await MainActor.run`（actor → MainActor 的跨隔离域调用）有一定开销，调试页面帧率下可接受；如果以后要接极高帧率的实时流水线，可以考虑改成订阅 `UIDeviceOrientationDidChangeNotification` 一次性缓存到 actor 内部状态，而不是每帧现读。

**验证**：`CameraFeature` 全部 9 条测试（含 `CameraPipelineBridgeTests` 里那条走真实 `CVMetalTextureCache` 的端到端测试）在 macOS host 上通过——这条测试路径现在会经过 `currentOrientation()` 的 `#else` 分支，验证了新代码不会破坏 macOS 编译/测试，但 iOS 分支本身（`UIDevice` 相关调用、`MainActor.run` 跨隔离域）没有 CLI 信号，仍需 Xcode/真机验证。

```
=== Shared ===        9 tests passed
=== CameraCore ===    3 tests passed
=== CameraPipeline === 7 tests passed
=== CameraVision ===  9 tests passed
=== CameraFeature === 9 tests passed（不变，本轮改动走的是已有测试覆盖的 handle() 路径）
```

## 相机内参提取（第六轮：`CameraCore.Frame.intrinsics`）

补上"已知简化"里最后一项——之前 `CameraPipelineBridge` 里 `FrameMetadata.intrinsics` 一直硬编码 `nil`。

- **`CameraCore.Frame`**（`Protocol/CameraSourceProtocol.swift`）新增 `intrinsics: simd_float3x3?` 字段，`init` 里给默认值 `nil`，两个已有调用点（`FrameOutputDelegate` 真实回调、`CameraPipelineBridgeTests` 里两处测试用的 2 参数构造）不用改。
- **`CameraSession.configureOutputs()`**：`videoDataOutput` `addOutput` 之后，`#if os(iOS)` 下查 `connection.isCameraIntrinsicMatrixDeliverySupported`，支持的话打开 `isCameraIntrinsicMatrixDeliveryEnabled`（这个属性必须在 `addOutput` 之后设置，connection 要加完 output 才存在）。
- **`FrameOutputDelegate`** 新增 `static func intrinsics(from sampleBuffer:) -> simd_float3x3?`：从 `CMSampleBuffer` 的 `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix` attachment 读 `Data`，`withUnsafeBytes` reinterpret 成 `matrix_float3x3`；没开 delivery 或设备不支持时 attachment 不存在，正常返回 `nil`（不是错误）。这个函数特意声明成 internal 而不是 `private`，方便单测直接喂合成的 `CMSampleBuffer` 验证提取逻辑，不需要在测试里构造一个真实的 `AVCaptureConnection`（那玩意儿脱离真实 session 几乎没法单独造出来）。
- **`CameraPipelineBridge.handle(_:)`**：`FrameMetadata(intrinsics: nil)` 换成 `FrameMetadata(intrinsics: frame.intrinsics)`，透传而不是硬编码。

**测试**：新增 `CameraCoreTests/FrameOutputDelegateIntrinsicsTests.swift`，用 `CMSampleBufferCreateForImageBuffer` 造一个真实（非 mock）`CMSampleBuffer`，两条用例：`CMSetAttachment` 手工挂一个已知的 `matrix_float3x3`（用 `withUnsafeBytes` 转 `Data`）后验证 `intrinsics(from:)` 能原样读出来（逐分量核对，不是只判断非 nil）；以及不挂 attachment 时返回 `nil`。`CameraCore` 从 3 条测试涨到 5 条。

**踩到的坑**：CameraCore 的 `Frame` 签名变了之后，第一次跑 `CameraFeature` 的 `swift test` 遇到链接错误——`Undefined symbols ... Frame.init(pixelBuffer:timestamp:)`，是 SwiftPM 增量构建缓存没有正确失效（`CameraFeatureTests.swift.o` 还是按旧的 2 参数签名编译的目标文件，没跟着 `CameraCore` 一起重新链接）。`rm -rf .build && swift test` clean 重建后恢复正常，不是代码问题。

```
=== Shared ===        12 tests passed
=== CameraCore ===    5 tests passed（新增 2 条：intrinsics 提取的正常/缺失路径）
=== CameraPipeline === 10 tests passed
=== CameraVision ===  9 tests passed
=== CameraFeature === 10 tests passed
```

**仍未验证**：`isCameraIntrinsicMatrixDeliverySupported` 在真机上是否真的对当前用的镜头返回 true（不是所有设备/镜头组合都支持内参交付）；即便支持，`FrameMetadata.intrinsics` 目前也还没有任何消费方读它（属于"数据管道通了，暂时没人用"的状态，等 Stage 4 或未来需要相机标定/AR 类功能时再接消费方）。

## 仍未完成的部分

Frame bridging 系列（本文档）到这里全部收尾——三条"已知简化"（设备朝向、直方图统计、相机内参）都已经是真实实现，不再是占位或硬编码值。剩下的都是需要真机才能确认的验证项，不是代码缺口：

1. 上方"设备朝向跟踪"一节的 iOS 分支（`UIDevice.current.orientation` 读取、`MainActor.run` 跨隔离域调用、朝向映射表是否正确）需要真机验证，包括横屏持机时预览/直方图是否仍然正确显示。
2. `isCameraIntrinsicMatrixDeliverySupported` 在真实设备/镜头组合上是否为 `true`，需要真机确认；`FrameMetadata.intrinsics` 目前没有消费方，留给未来需要相机标定的功能使用。
3. Stage 3 收尾（Vision 检测接入、文档裁剪落盘）已经在 `stage3_camera_vision_plan.md` 的 "A1"/"A2" 章节里单独记录，不重复列在这里。

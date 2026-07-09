# Speech Plan 2: 搭建 SpeechKit (ASR 部分)

## 背景

在 `SpeechAbstraction` 协议就绪后，本计划创建 `SpeechKit` (Utilities 层) 包，真正引入 speech-swift 依赖，实现语音转文字（ASR）部分：麦克风管理、Parakeet 模型加载/推理、首次下载管理。

**来源**：`docs/specs/speech_swift_integration_plan.md` 阶段 2

## 步骤

### Step 1: 新建 `SpeechKit` SPM 包

路径：`Packages/Utilities/SpeechKit/`

在 `Package.swift` 中添加以下依赖：
- `SpeechAbstraction`（项目内依赖）
- `AudioCommon`（speech-swift，共享音频 I/O 与 HG 下载器）
- `ParakeetASR`（speech-swift，ASR 模型）
- `RxSwift`（项目标准依赖）

使用标准的 `.internal()` / `.external()` 依赖 helper 模式。

### Step 2: 实现 `SpeechPermissionManager`

封装麦克风权限请求与状态查询：

```swift
import AVFoundation

public class SpeechPermissionManager {
    public enum PermissionStatus {
        case notDetermined, granted, denied
    }
    
    public var currentStatus: PermissionStatus { ... }
    public func requestPermission() -> Observable<PermissionStatus> { ... }
}
```

不暴露 AVFoundation 类型给外部。

### Step 3: 实现 `SpeechModelDownloadMonitor`

包装 speech-swift 的模型下载状态，转换成 `SpeechModelDownloadStatus` 对外暴露：

```swift
public class SpeechModelDownloadMonitor {
    public var downloadStatus: Observable<SpeechModelDownloadStatus> { ... }
    // 触发下载
    public func ensureModelReady() -> Observable<SpeechModelDownloadStatus>
}
```

核心逻辑：
- 检查模型文件是否存在（本地缓存判断）
- 如果不存在，通过 speech-swift 底层的 HuggingFace 下载器开始下载
- 流式汇报进度 → `.downloading(progress:)`
- 下载完成 → `.ready`
- 失败 → `.failed(Error)`

### Step 4: 实现 `ParakeetSpeechRecognizer`

实现 `SpeechRecognizerProtocol`：

```swift
public class ParakeetSpeechRecognizer: SpeechRecognizerProtocol {
    private let audioEngine = AVAudioEngine()
    private let asrModel: ParakeetASRModel
    
    public var isModelReady: Bool
    
    public func startListening() -> Observable<SpeechRecognitionResult>
    public func stopListening()
}
```

核心逻辑：
1. `startListening()` 创建 Observable，订阅时：
   - 请求麦克风权限（如果未授权）
   - 确保模型已下载（触发 download monitor）
   - 启动 AVAudioEngine 采集麦克风音频
   - 将音频 buffer 送入 Parakeet 模型推理
   - 流式 emit 识别中间结果与最终结果
2. `stopListening()` 停止 AVAudioEngine，结束 Observable
3. 内部持有 DisposeBag 管理订阅生命周期

### Step 5: DI 注册

在 `DI/SpeechKitAssembly.swift` 中：

```swift
extension DIContainer {
    public static func registerSpeechKitASR() {
        DIContainer.shared.register(SpeechRecognizerProtocol.self) { _ in
            ParakeetSpeechRecognizer()
        }
        DIContainer.shared.register(SpeechPermissionManager.self) { _ in
            SpeechPermissionManager()
        }
        DIContainer.shared.register(SpeechModelDownloadMonitor.self) { _ in
            SpeechModelDownloadMonitor()
        }
    }
}
```

### Step 6: 创建简单测试页验证 ASR（可选辅助）

在 `ModuleTest` tab 或独立 SwiftUI 预览中添加一个简单页面：
- 麦克风按钮 → 开始/停止录音
- 展示实时识别文字
- 展示模型下载状态

## 涉及文件清单

- `Packages/Utilities/SpeechKit/Package.swift`（新建）
- `Packages/Utilities/SpeechKit/Sources/SpeechKit/SpeechPermissionManager.swift`（新建）
- `Packages/Utilities/SpeechKit/Sources/SpeechKit/SpeechModelDownloadMonitor.swift`（新建）
- `Packages/Utilities/SpeechKit/Sources/SpeechKit/ParakeetSpeechRecognizer.swift`（新建）
- `Packages/Utilities/SpeechKit/Sources/SpeechKit/DI/SpeechKitAssembly.swift`（新建）
- `MyEcommerceApp/MyEcommerceApp.swift`（修改，追加 `registerSpeechKitASR()`）

## 验收标准

- [ ] `SpeechKit` 包可编译，依赖 speech-swift 无冲突
- [ ] 麦克风权限申请流程正常，拒绝后有降级处理
- [ ] 模型下载状态正确反映（下载中/完成/失败）
- [ ] 能完成一次完整的"说话 → 识别文字"流程
- [ ] 停止录音后资源正确释放

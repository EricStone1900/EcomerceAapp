# Speech Plan 1: 确认约束 + 搭建 SpeechAbstraction 包

## 背景

语音搜索与商品播报功能的第一步。本计划确立最低部署版本的决策，并创建 `SpeechAbstraction` 包——一个纯协议层，定义语音能力接口，不依赖任何具体第三方库。

**来源**：`docs/specs/speech_swift_integration_plan.md` 阶段 1

## 步骤

### Step 1: 确认最低部署版本决策

**结论：已确认当前最低版本为 iOS 18**（所有 SPM 包均在 `Package.swift` 中声明 `.iOS(.v18)`），满足 Parakeet ASR / Kokoro TTS 的 iOS 18+ 要求，无需额外改动。

记录到此计划中即可，无需修改项目配置。

### Step 2: 新建 `SpeechAbstraction` SPM 包

在 `Packages/Abstraction/Sources/Abstraction/` 下创建 `SpeechAbstraction` 目录，定义以下纯协议与数据模型：

**数据模型（纯 struct/enum，无依赖）：**

```swift
public struct SpeechRecognitionResult: Equatable {
    public let text: String
    public let isFinal: Bool
    public let confidence: Float?
}

public enum SpeechVoiceOption: Equatable {
    case kokoro(String)   // voice id, e.g. "af_heart"
}

public enum SpeechPlaybackStatus: Equatable {
    case playing
    case finished
    case failed(Error)
}

public enum SpeechModelDownloadStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case ready
    case failed(Error)
}
```

> 注意：Equatable conformance 对 `Error` 类型的 case 需要通过 `extension` 或其他方式处理。

**协议定义：**

```swift
import RxSwift

public protocol SpeechRecognizerProtocol: AnyObject {
    var isModelReady: Bool { get }
    func startListening() -> Observable<SpeechRecognitionResult>
    func stopListening()
}

public protocol SpeechSynthesizerProtocol: AnyObject {
    func speak(text: String, voice: SpeechVoiceOption) -> Observable<SpeechPlaybackStatus>
    func stopSpeaking()
}
```

所有协议使用 `AnyObject` 约束，确保引用语义，方便 DI 注册。

### Step 3: 在 `Packages/Abstraction/Package.swift` 中注册 `SpeechAbstraction` 目标

按项目的 `CaseIterable` 枚举模式，在 Abstraction 包的 `Product` 枚举中添加新 case：

```swift
case SpeechAbstraction
```

并在 `dependencies` / `testsDependencies` 计算属性中配置（纯协议层，依赖与 Mock 层类似，仅有 RxSwift）。

### Step 4: 编写存根验收

- `cd Packages/Abstraction && swift build` 编译通过
- 包不包含任何 speech-swift 或 AVFoundation 的 import（纯协议层）

## 涉及文件清单

- `Packages/Abstraction/Sources/Abstraction/SpeechAbstraction/SpeechRecognizerProtocol.swift`（新建）
- `Packages/Abstraction/Sources/Abstraction/SpeechAbstraction/SpeechSynthesizerProtocol.swift`（新建）
- `Packages/Abstraction/Sources/Abstraction/SpeechAbstraction/Models.swift`（新建，数据模型）
- `Packages/Abstraction/Sources/Abstraction/SpeechAbstraction/DI/DIContainer+SpeechAbstraction.swift`（新建，空注册桩）
- `Packages/Abstraction/Package.swift`（修改，新增 SpeechAbstraction target）

## 验收标准

- [ ] `SpeechAbstraction` 包可独立编译，无任何实现逻辑
- [ ] 所有协议 clean，不引用 speech-swift、AVFoundation 等具体库

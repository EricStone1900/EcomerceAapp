# Speech Plan 3: 搭建 SpeechKit (TTS 部分)

## 背景

基于 `SpeechKit` 包的已有基础设施，本计划增加文字转语音（TTS）能力。引入 speech-swift 的 KokoroTTS 模型，实现文字到语音播报的完整链路。

**来源**：`docs/specs/speech_swift_integration_plan.md` 阶段 3

## 步骤

### Step 1: 在 `SpeechKit/Package.swift` 中添加 KokoroTTS 依赖

在现有依赖基础上追加：
- `KokoroTTS`（speech-swift，TTS 模型）
- 与 ASR 共用 `AudioCommon`（无需重复添加）

### Step 2: 实现 `KokoroSpeechSynthesizer`

实现 `SpeechSynthesizerProtocol`：

```swift
public class KokoroSpeechSynthesizer: SpeechSynthesizerProtocol {
    private let ttsModel: KokoroTTSModel
    private let audioPlayer: AVAudioPlayer?
    
    public func speak(text: String, voice: SpeechVoiceOption) -> Observable<SpeechPlaybackStatus>
    public func stopSpeaking()
}
```

核心逻辑：
1. `speak(text:voice:)` 创建 Observable，订阅时：
   - 确保 Kokoro 模型已下载（与 ASR 模型共享或独立 download monitor）
   - 调用 `KokoroTTSModel.synthesize(text:voice:)` 生成 PCM 音频数据
   - 使用 `AVAudioPlayer` 或 `AVAudioEngine` 播放
   - 播放完成 → emit `.finished`
   - 播放失败 → emit `.failed(Error)`
2. `stopSpeaking()` 停止播放，中断 Observable

**音色映射**：`SpeechVoiceOption.kokoro("af_heart")` 直接透传给 Kokoro 的 voice ID 参数。可以预定义几个常用音色作为 static 常量：

```swift
extension SpeechVoiceOption {
    public static let defaultFemale = SpeechVoiceOption.kokoro("af_heart")
    public static let defaultMale = SpeechVoiceOption.kokoro("am_bryce")
}
```

### Step 3: 在 DI 中注册 TTS

在 `SpeechKitAssembly.swift` 中追加：

```swift
extension DIContainer {
    public static func registerSpeechKitTTS() {
        DIContainer.shared.register(SpeechSynthesizerProtocol.self) { _ in
            KokoroSpeechSynthesizer()
        }
    }
}
```

### Step 4: 验证 TTS 链路

创建简单的测试入口验证：
- 输入文字 → 点击播报 → 听到声音
- 播报过程中点击停止 → 声音停止
- 切换音色 → 效果不同

## 涉及文件清单

- `Packages/Utilities/SpeechKit/Package.swift`（修改，追加 KokoroTTS 依赖）
- `Packages/Utilities/SpeechKit/Sources/SpeechKit/KokoroSpeechSynthesizer.swift`（新建）
- `Packages/Utilities/SpeechKit/Sources/SpeechKit/DI/SpeechKitAssembly.swift`（修改，追加 TTS 注册）
- `MyEcommerceApp/MyEcommerceApp.swift`（修改，追加 `registerSpeechKitTTS()`）

## 验收标准

- [ ] 编译通过，KokoroTTS 依赖正常链接
- [ ] 输入文字后能正常播报语音
- [ ] 音色（voice）可配置且生效
- [ ] 播报过程中可以正常中断（`stopSpeaking`）
- [ ] 页面退出时播放自动停止，无内存泄漏

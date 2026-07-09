# Speech Plan 7: 文档收尾与集成验证

## 背景

语音功能全部实现后，本计划完成文档收尾工作：更新架构文档、补充 CLAUDE.md 的语音调用规范、记录 Info.plist 权限文案、最后完成整体集成回归验证。

**来源**：`docs/specs/speech_swift_integration_plan.md` 阶段 7

## 步骤

### Step 1: 更新 `docs/architecture.md`

补充 `SpeechAbstraction` / `SpeechKit` 模块在图中的位置说明：

```
Utilities:
  ├── Networking/API         — HTTP 请求
  ├── Analytics              — 事件埋点
  ├── ImageLoading           — Kingfisher 封装
  ├── DesignSystem           — 设计令牌
  ├── PresentationCore       — 基类、路由基座
  └── SpeechKit (NEW)        — 语音识别与合成（Parakeet + Kokoro）
```

在架构图中添加语音层的数据流路径：
```
[麦克风按钮] → VoiceSearchProductsUseCase → SpeechRecognizerProtocol
                                                  ↓
                                          ParakeetSpeechRecognizer
                                                  ↓
                                          ParakeetASR (speech-swift)
```

### Step 2: 更新 `CLAUDE.md`

在已有 ImageLoading Usage 区域后追加语音能力规范：

```
## Speech/语音能力

### 核心约束：依赖倒置

业务层（Feature/Domain）只依赖 `SpeechAbstraction` 包中的协议，不直接 import speech-swift：

```swift
// Feature 层正确做法
import SpeechAbstraction      // ✅
import RxSwift

// ❌ 不要直接 import speech-swift
// import ParakeetASR
// import KokoroTTS
```

### 可用协议

| 协议 | 用途 | 所在包 |
|------|------|--------|
| `SpeechRecognizerProtocol` | 语音转文字（ASR） | SpeechAbstraction |
| `SpeechSynthesizerProtocol` | 文字转语音（TTS） | SpeechAbstraction |

### UseCase 使用示例

```swift
// Domain/UseCase 层编排
final class VoiceSearchProductsUseCase {
    private let recognizer: SpeechRecognizerProtocol
    private let searchUseCase: SearchProductsUseCase

    func execute() -> Observable<VoiceSearchState> {
        // 编排语音识别 + 商品搜索
    }
}
```

### 权限

语音功能需要 `Info.plist` 配置：
- `NSMicrophoneUsageDescription` — 语音搜索需要访问麦克风

### 模型下载

- 语音模型在首次使用时自动下载（约 80~200MB）
- 仅首次下载需要联网，之后完全离线推理
- 推荐在 Wi-Fi 环境下首次使用
- 下载进度可通过 `SpeechModelDownloadStatus` 获取
```

### Step 3: 记录 Info.plist 权限文案

确认 `Info.plist` 中包含：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>语音搜索功能需要访问您的麦克风，说出商品名称即可快速搜索</string>
```

如果项目支持国际化，记录中英文文案到文档。

### Step 4: Info.plist 权限文案说明文档

在 `docs/specs/` 下创建 `speech_permissions.md`（可选），方便审核提交时同步文案给相关同学。

### Step 5: 整体集成回归验证

验证以下端到端场景：

| # | 场景 | 步骤 | 预期 |
|---|------|------|------|
| 1 | 首次语音搜索 | 打开 App → 点击麦克风 → 允许权限 → 说话 | 模型下载 → 识别 → 搜索 |
| 2 | 已下载模型后语音搜索 | 如上，但模型已就绪 | 无下载流程，直接进入聆听 |
| 3 | 商品详情播报 | 打开商品详情 → 点击朗读 | 语音播报商品信息 |
| 4 | 播报中停止 | 正在播报时点击停止按钮 | 声音停止 |
| 5 | 麦克风权限拒绝 | 拒绝权限后点击麦克风 | 引导弹窗，不崩溃 |
| 6 | 无网络下载 | 关闭网络后首次使用 | 下载失败提示 |
| 7 | 页面切换 | 语音搜索中切换 tab | 语音停止，无崩溃 |
| 8 | 低内存场景 | 后台运行其他 App 后返回 | 语音功能可继续使用 |
| 9 | 模拟器运行 | 用模拟器打开语音功能 | 功能可用（性能较低） |
| 10 | 依赖检查 | grep 搜索 Feature 代码 | 无 speech-swift import |

## 涉及文件清单

- `docs/architecture.md`（修改，补充 SpeechKit 模块）——如文件存在
- `CLAUDE.md`（修改，补充语音能力规范）
- `MyEcommerceApp/Info.plist`（确认/补充麦克风权限文案）
- `docs/specs/speech_permissions.md`（新建，可选）
- 所有 Feature 代码（回归验证，确保不直接 import speech-swift）

## 验收标准

- [ ] `docs/architecture.md` 已补充语音模块说明
- [ ] `CLAUDE.md` 已包含语音调用规范
- [ ] `Info.plist` 权限文案完整且正确
- [ ] 所有 Feature 包不直接 import speech-swift
- [ ] 语音搜索、商品播报两条链路端到端验证通过
- [ ] 所有异常场景均已覆盖且不崩溃

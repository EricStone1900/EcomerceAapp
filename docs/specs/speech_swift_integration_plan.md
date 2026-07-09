# speech-swift 语音能力集成实现计划（语音搜索 + 商品语音播报）

> 项目：EcommerceAppDemo（iOS · Clean Architecture · SPM 模块化）
> 集成库：https://github.com/soniqo/speech-swift（端上 AI 语音工具箱，MLX + CoreML）
> 选型：ParakeetASR（语音转文字，用于语音搜索）+ KokoroTTS（文字转语音，用于商品信息播报）
> 说明：本文档为实现计划，不含具体代码实现

---

## 一、项目整体架构回顾

项目采用 **Clean Architecture + SPM 模块化**，严格依赖倒置：外层依赖内层协议，内层不知道外层的存在。

```
Presentation/Features  →  Domain  →  Abstraction  ←  Data
        │                                           ↑
        │                    ┌──────────────────────┘
        └──── Utilities ─────┘
```

| 层 | 职责 | 依赖规则 |
|---|---|---|
| **Abstraction** | 纯协议层 | 仅 Swinject/RxSwift；UIKit/AVFoundation 不算"项目依赖" |
| **Domain** | UseCase 业务编排 | 仅依赖 Abstraction 协议 |
| **Data** | Repository/Service 具体实现 | 依赖 Abstraction 协议 |
| **Presentation** | SwiftUI Feature 包（`ProductsFeature`/`BasketFeature` 等） | 依赖 Domain 协议、Abstraction、Utilities |
| **Utilities** | 横切工具，被所有 Feature 共用（如 `Analytics`、`Networking`） | 可依赖 Abstraction 协议 |
| **App 层** | 组合根 | 唯一允许"知道所有 Feature"的层 |

**本次集成的定位判断**：语音识别/合成的"能力"本身（麦克风采集、模型推理、音频播放）是设备能力封装，跟 `Networking`、`Analytics` 一样属于 Utilities 层横切基础设施；但"用户说了什么之后要不要触发商品搜索""哪个商品详情页需要播报"这类业务决策，属于具体 Feature 的 Domain 层职责。因此本次采用**双层设计**：Utilities 层封装原始语音能力，各 Feature 的 Domain 层编排"语音能力 + 业务逻辑"的组合调用。

## 如何使用现有工程

- `xed .` 打开工程，DEBUG 默认走 Mock API（`-environment dev`），无需后端即可跑通全流程
- 新增业务模块标准套路：Abstraction 定协议 → Domain 写 UseCase → Data/Utilities 写具体实现 → Presentation 写 View/ViewModel → 各层 DI 注册
- 单测：`cd Packages/<层>/<包名> && swift test`

---

## 二、集成前必须确认的约束条件

| 约束项 | 说明 | 需要的决策 |
|---|---|---|
| **最低部署版本** | Parakeet ASR、Kokoro TTS 均要求 **iOS 18+** | 需要评估工程当前最低支持版本是否要提升到 iOS 18；如果工程需要兼容更低版本，语音功能需要做**条件降级**（低版本隐藏语音入口，或退化到 Apple 系统自带的 `Speech`/`AVSpeechSynthesizer`） |
| **模型下载** | 首次使用时从 HuggingFace 自动下载模型权重（Kokoro 约 80~170MB，视量化档位；Parakeet 模型体积另需在接入时以实际打包结果为准），下载后离线可用 | 需要设计首次下载的 UX（进度提示、Wi-Fi 环境提醒、失败重试），不能让用户在无感知情况下消耗大量移动流量 |
| **网络要求** | 仅首次下载需要联网，此后完全离线推理，无需 API Key、无云端调用 | 无额外后端改造需求，符合项目"离线优先"的产品调性 |
| **设备兼容性** | CoreML 模型跑在 Neural Engine 上，模拟器也支持（会有性能差异，falls back 到 CPU），真机体验更接近真实指标 | 测试计划需覆盖真机和模拟器两种场景 |
| **麦克风权限** | 语音搜索需要用户授权麦克风访问 | 需要在 `Info.plist` 增加权限描述文案，并设计好拒绝权限后的降级体验（如提示引导去设置里开启，而不是崩溃或静默失败） |
| **内存占用** | 语音模型加载后常驻一定内存 | 需要设计懒加载策略：只有用户主动触发语音功能时才加载模型，退出该功能场景后视情况释放 |

---

## 三、模块设计

### 1. `SpeechAbstraction`（Abstraction 层，新 SPM 包）

纯协议 + 数据模型，零实现，不感知 speech-swift 这个具体第三方库的存在：

- `SpeechRecognizerProtocol`：
  - `func startListening() -> Observable<SpeechRecognitionResult>`（流式返回识别中间结果与最终结果，与项目里 RxSwift 优先的编排风格保持一致）
  - `func stopListening()`
  - `var isModelReady: Bool`（模型是否已下载完成，可用于 UI 判断是否要提示下载）
- `SpeechSynthesizerProtocol`：
  - `func speak(text: String, voice: SpeechVoiceOption) -> Observable<SpeechPlaybackStatus>`
  - `func stopSpeaking()`
- `SpeechRecognitionResult`：识别文本、是否为最终结果、置信度（如果底层库暴露）
- `SpeechVoiceOption`：语音音色标识（对应 Kokoro 的 voice id，如 `af_heart`）、语言
- `SpeechPlaybackStatus`：`.playing` / `.finished` / `.failed(Error)`
- `SpeechModelDownloadStatus`：`.notDownloaded` / `.downloading(progress: Double)` / `.ready` / `.failed(Error)`，供 UI 展示首次下载进度

### 2. `SpeechKit`（Utilities 层，新 SPM 包，路径 `Packages/Utilities/SpeechKit/`）

真正引入 speech-swift 依赖并做具体实现的地方：

- 依赖 speech-swift 的 `ParakeetASR`、`KokoroTTS`、`AudioCommon`（共享基础设施，音频 I/O、HuggingFace 下载器）
- `ParakeetSpeechRecognizer`：实现 `SpeechRecognizerProtocol`，内部管理麦克风采集（`AVAudioEngine`）、调用 Parakeet 模型做流式识别、通过 RxSwift `Observable` 对外发布结果
- `KokoroSpeechSynthesizer`：实现 `SpeechSynthesizerProtocol`，内部调用 `KokoroTTSModel.synthesize(text:voice:)` 生成 PCM 音频，用 `AVAudioPlayer`/`AVAudioEngine` 播放
- `SpeechModelDownloadMonitor`：包装 speech-swift 的模型下载状态，转换成 `SpeechModelDownloadStatus` 对外暴露
- `SpeechPermissionManager`：封装麦克风权限请求与状态查询
- `DI/SpeechKitAssembly.swift`：注册以上具体实现到 `SpeechRecognizerProtocol`/`SpeechSynthesizerProtocol`

### 3. 各 Feature 包的 Domain 层新增 UseCase

以 `ProductsFeature`（对应的 `ProductsDomain`）为例：

- `VoiceSearchProductsUseCase`：注入 `SpeechRecognizerProtocol` + 已有的商品搜索 UseCase，编排"监听语音 → 拿到最终识别文本 → 调用商品搜索"这一整套流程，对 Presentation 层只暴露一个统一的调用入口，不需要 ViewModel 自己去操心语音识别的中间状态管理
- `SpeakProductDetailUseCase`：注入 `SpeechSynthesizerProtocol`，接收商品的名称/描述文本，组装成适合朗读的文案（比如把价格、促销信息转成更口语化的表达）后调用播报

`BasketFeature` 如果也需要语音播报购物车内容摘要，同理新增对应 UseCase，复用同一个 `SpeechSynthesizerProtocol`，不重复造轮子。

### 4. Presentation 层改动

- `ProductsFeature` 的商品列表/搜索页：新增一个麦克风按钮，点击后调用 `VoiceSearchProductsUseCase`，UI 侧展示"聆听中"的动画状态与实时识别文本预览
- `ProductsFeature` 的商品详情页：新增一个"朗读商品信息"按钮，调用 `SpeakProductDetailUseCase`
- 首次使用前，如果 `SpeechModelDownloadStatus` 不是 `.ready`，展示下载进度提示（可复用之前设计的 `DesignSystem`/`ComponentKit` 里的通用加载态组件）

### 5. App 层组合根

- `MyEcommerceApp.init()` 追加 `SpeechAbstraction` 无需注册（纯协议），追加 `SpeechKit` 的 DI 注册
- 视产品体验需要，决定模型下载是在 App 启动时预热，还是延迟到用户首次点击语音功能时才触发（**建议后者**，避免拖慢启动速度、避免非语音用户被迫消耗流量下载用不到的模型）

---

## 四、分阶段实施计划

### 阶段 1：确认约束 + 搭建 SpeechAbstraction

- 拍板最低部署版本决策（提升到 iOS 18，或做条件降级方案）
- 新建 `SpeechAbstraction` 包，实现本文第三节列出的全部协议/数据模型
- **验收**：
  - [ ] 包可独立编译，无实现逻辑
  - [ ] 部署版本决策已明确并记录在项目文档中

### 阶段 2：接入 speech-swift，搭建 SpeechKit —— ASR 部分

- 新建 `SpeechKit` 包，依赖 speech-swift 的 `ParakeetASR` + `AudioCommon`
- 实现 `ParakeetSpeechRecognizer`、`SpeechPermissionManager`、`SpeechModelDownloadMonitor`（先针对 ASR 部分）
- **验收**：
  - [ ] 麦克风权限申请流程正常，拒绝权限后有合理提示
  - [ ] 能完成一次完整的"说话 → 拿到文字识别结果"流程（用简单的 Demo 页面或单测辅助验证）
  - [ ] 模型下载状态能正确反映（下载中/完成/失败）

### 阶段 3：搭建 SpeechKit —— TTS 部分

- 依赖 speech-swift 的 `KokoroTTS`
- 实现 `KokoroSpeechSynthesizer`
- **验收**：
  - [ ] 能完成一次完整的"输入文字 → 播放语音"流程
  - [ ] 音色（voice）可配置且生效
  - [ ] 播放过程中可以正常中断（`stopSpeaking`）

### 阶段 4：ProductsFeature 接入语音搜索

- 新增 `VoiceSearchProductsUseCase`
- 商品搜索页新增麦克风入口与"聆听中"状态 UI
- **验收**：
  - [ ] 说出商品关键词后，能触发对应的商品搜索并展示结果
  - [ ] 识别失败/无网络下载模型时，有合理的降级提示，不会崩溃或无响应

### 阶段 5：ProductsFeature/BasketFeature 接入商品语音播报

- 新增 `SpeakProductDetailUseCase`（及 `BasketFeature` 对应的购物车摘要播报，如需要）
- 商品详情页新增"朗读"按钮
- **验收**：
  - [ ] 点击朗读后能正常播报商品信息，语速语调可接受
  - [ ] 页面离开时，正在播放的语音能正确停止，不会内存泄漏或后台持续占用

### 阶段 6：性能与体验打磨

- 验证真机与模拟器下的实际表现差异
- 验证模型懒加载策略：非语音功能场景下不占用额外内存
- 验证首次下载的网络提示体验（建议 Wi-Fi 环境下静默下载，蜂窝网络下需二次确认）

### 阶段 7：文档收尾

- 更新 `docs/architecture.md`，补充 `SpeechAbstraction`/`SpeechKit` 模块说明
- 更新 `CLAUDE.md`，注明语音能力的调用规范（业务方只依赖 `SpeechAbstraction` 协议，不直接 import speech-swift）
- 补充 `Info.plist` 权限文案说明文档，方便审核提交时同步给相关同学

---

## 五、验收标准总览

- [ ] `ProductsFeature`、`BasketFeature` 均不直接 import speech-swift，只依赖 `SpeechAbstraction` 协议
- [ ] 语音搜索、商品播报两条链路均可在真机上正常工作
- [ ] 麦克风权限拒绝、模型下载失败、无网络等异常场景均有合理降级，不崩溃
- [ ] 模型下载与加载策略是懒加载，不拖慢 App 启动、不占用非语音用户的流量与内存
- [ ] 最低部署版本决策已落地（提升版本或条件降级二选一，且已验证生效）
- [ ] 如未来需要替换成 speech-swift 的其他模型（如更高精度的 Qwen3-ASR，但需注意其为 MLX 后端，仅支持 macOS 不支持 iOS），只需改动 `SpeechKit` 内部实现，不影响已接入的 Feature 代码

---

*本文档为实现计划，不含具体代码实现。*

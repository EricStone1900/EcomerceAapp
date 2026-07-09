# Speech Plan 4: 语音搜索接入 (ProductsFeature)

## 背景

ASR 能力就绪后，本计划将语音搜索集成到商品搜索功能。新增 `VoiceSearchProductsUseCase` 编排"监听语音 → 识别文本 → 商品搜索"流程，并在 UI 层增加麦克风入口与"聆听中"状态。

**来源**：`docs/specs/speech_swift_integration_plan.md` 阶段 4

## 步骤

### Step 1: 新增 `VoiceSearchProductsUseCase`

位置：`Packages/Domain/Sources/Domain/ProductsDomain/UseCases/`

注入依赖：
- `SpeechRecognizerProtocol`
- 已有的商品搜索 UseCase（`SearchProductsUseCase` 或其他）

```swift
public class VoiceSearchProductsUseCase {
    private let speechRecognizer: SpeechRecognizerProtocol
    private let searchUseCase: SearchProductsUseCase
    
    public func execute(
        trigger: Observable<Void>
    ) -> Observable<VoiceSearchState>
}
```

**状态模型**：

```swift
public enum VoiceSearchState: Equatable {
    case idle                        // 初始状态
    case preparing                   // 模型加载/权限申请中
    case listening(interimText: String) // 正在聆听，展示实时识别文字
    case processing(text: String)    // 识别完成，正在搜索
    case results([Product])          // 搜索结果
    case noResults(query: String)    // 无匹配结果
    case error(Error)                // 出错
}
```

**编排逻辑**：
1. `trigger` 事件触发 → 进入 `.preparing`
2. 检查 `isModelReady`，如未就绪触发模型下载
3. 请求麦克风权限
4. 调用 `speechRecognizer.startListening()`
5. 流式接收中间结果 → `.listening(interimText:)`
6. 收到最终结果 → `.processing(text:)` → 调用 `searchUseCase` → 返回 `.results` 或 `.noResults`
7. 如果中间过程任意一步出错 → `.error`

### Step 2: 注册 UseCase 的 DI

```swift
extension DIContainer {
    public static func registerVoiceSearchUseCase() {
        DIContainer.shared.register(VoiceSearchProductsUseCase.self) { resolver in
            VoiceSearchProductsUseCase(
                speechRecognizer: resolver.resolve(SpeechRecognizerProtocol.self)!,
                searchUseCase: resolver.resolve(SearchProductsUseCase.self)!
            )
        }
    }
}
```

### Step 3: 在商品搜索页添加麦克风入口

**位置**：`Packages/Presentation/ProductsFeature/` 中的商品列表/搜索页

- 在搜索栏旁边或搜索输入框内添加麦克风图标按钮
- 点击 → 触发 `VoiceSearchProductsUseCase` 的 trigger
- 根据 `voiceSearchState` 展示不同 UI：

| 状态 | UI 表现 |
|------|---------|
| `.idle` | 无变化，麦克风按钮可用 |
| `.preparing` | 按钮转为加载指示器 + "准备中" |
| `.listening` | 按钮变为红色脉冲动画 + 显示"聆听中..." + 实时识别文字预览 |
| `.processing` | 按钮禁用 + "正在搜索..." |
| `.results` | 显示搜索列表，恢复按钮到 idle |
| `.noResults` | 展示"未找到与「xxx」相关的商品"提示 |
| `.error` | Toast 提示错误信息 |

### Step 4: 处理首次下载提示

当语音模型首次未下载时，展示下载进度条（可复用 DesignSystem 的组件）：

- 弹窗或内联提示："首次使用需要下载语音模型（约 XX MB），推荐在 Wi-Fi 环境下载"
- 展示实时下载进度百分比
- 下载完成后自动进入准备状态
- 下载失败展示重试按钮

### Step 5: 权限拒绝处理

如果用户拒绝了麦克风权限：
- 不崩溃
- 展示提示："麦克风权限被拒绝，请前往设置开启后使用语音搜索"
- 可选提供"去设置"按钮（`UIApplication.openSettingsURLString`）
- 麦克风按钮保持可见但不可用，或隐藏并提示打开位置

## 涉及文件清单

- `Packages/Domain/Sources/Domain/ProductsDomain/UseCases/VoiceSearchProductsUseCase.swift`（新建）
- `Packages/Domain/Sources/Domain/ProductsDomain/DI/DIContainer+ProductsDomain.swift`（修改，追加注册）
- `Packages/Presentation/ProductsFeature/Sources/.../Views/ProductSearchView.swift`（修改，增加麦克风入口）
- `Packages/Presentation/ProductsFeature/Sources/.../ViewModels/ProductSearchViewModel.swift`（修改，增加语音搜索逻辑）
- `MyEcommerceApp/MyEcommerceApp.swift`（修改，追加注册）

## 验收标准

- [ ] 说出商品关键词（如"沙发"）后能触发搜索并展示结果
- [ ] 聆听中展示实时识别文字预览
- [ ] 无匹配结果时有合理提示
- [ ] 模型未下载时展示下载进度
- [ ] 麦克风权限拒绝后有引导提示，不崩溃
- [ ] 搜索中途可以取消聆听

# Speech Plan 5: 商品语音播报接入

## 背景

TTS 能力就绪后，本计划将语音播报集成到商品详情页与购物车页。新增 `SpeakProductDetailUseCase` 组装商品信息成适合朗读的文案，注入 `SpeechSynthesizerProtocol` 播报。

**来源**：`docs/specs/speech_swift_integration_plan.md` 阶段 5

## 步骤

### Step 1: 新增 `SpeakProductDetailUseCase`

位置：`Packages/Domain/Sources/Domain/ProductsDomain/UseCases/`

```swift
public class SpeakProductDetailUseCase {
    private let speechSynthesizer: SpeechSynthesizerProtocol
    
    public func speak(product: Product) -> Observable<SpeechPlaybackStatus>
    public func stopSpeaking()
}
```

**文案组装逻辑**：

将商品信息转成口语化文案，例如：
> "这是「简约现代布艺沙发」，价格 ¥2999，目前库存充足，可享 3 期免息分期。"

组装规则（写在 UseCase 内部）：
- 商品名称直接引用
- 价格添加货币单位
- 如果有促销信息，加入"优惠活动：..."
- 如果有库存信息，加入"库存充足/仅剩 X 件"
- 可读性优化：数字读法、标点符号转停顿

### Step 2: 新增 `SpeakBasketSummaryUseCase` (BasketFeature)

购物车摘要播报——必选实现：

```swift
public class SpeakBasketSummaryUseCase {
    private let speechSynthesizer: SpeechSynthesizerProtocol
    private let getBasketUseCase: GetBasketUseCaseProtocol
    
    public func speakBasketSummary() -> Observable<SpeechPlaybackStatus>
    public func stopSpeaking()
}
```

文案示例：
> "您的购物车共有 3 件商品，总计 ¥5,890。最贵的商品是「真皮沙发」¥3,999。"

### Step 3: DI 注册

```swift
extension DIContainer {
    public static func registerSpeakProductUseCase() {
        DIContainer.shared.register(SpeakProductDetailUseCase.self) { resolver in
            SpeakProductDetailUseCase(
                speechSynthesizer: resolver.resolve(SpeechSynthesizerProtocol.self)!
            )
        }
        // 如果需要购物车播报
        DIContainer.shared.register(SpeakBasketSummaryUseCase.self) { resolver in
            SpeakBasketSummaryUseCase(
                speechSynthesizer: resolver.resolve(SpeechSynthesizerProtocol.self)!,
                getBasketUseCase: resolver.resolve(GetBasketUseCaseProtocol.self)!
            )
        }
    }
}
```

### Step 4: 商品详情页添加"朗读"按钮

**位置**：`Packages/Presentation/ProductsFeature/` 中的商品详情页

- 在价格/描述区域下方或右上角添加一个喇叭/朗读图标按钮
- 点击 → 调用 `SpeakProductDetailUseCase.speak(product:)`
- 播报中按钮变为停止图标，可点击停止
- 播报完成按钮恢复

### Step 5: 购物车页添加摘要播报

在购物车页顶部或底部添加"语音播报购物车摘要"按钮：
- 点击后播报购物车内容摘要
- 在 `BasketViewModel` 中注入 `SpeakBasketSummaryUseCase`
- 播报中按钮切换为停止图标

### Step 6: 页面生命周期管理

在 ViewModel 中持有 `SpeakProductDetailUseCase`，在页面 `onDisappear` 时调用 `stopSpeaking()`：

```swift
// ViewModel
private let speakUseCase: SpeakProductDetailUseCase

func onDisappear() {
    speakUseCase.stopSpeaking()
}
```

确保：
- 页面离开时正在播放的语音正确停止
- 不造成内存泄漏
- 不出现后台持续占用麦克风/音频资源

## 涉及文件清单

- `Packages/Domain/Sources/Domain/ProductsDomain/UseCases/SpeakProductDetailUseCase.swift`（新建）
- `Packages/Domain/Sources/Domain/ProductsDomain/DI/DIContainer+ProductsDomain.swift`（修改，追加注册）
- `Packages/Domain/Sources/Domain/BasketDomain/UseCases/SpeakBasketSummaryUseCase.swift`（新建）
- `Packages/Domain/Sources/Domain/BasketDomain/DI/DIContainer+BasketDomain.swift`（修改，追加注册）
- `Packages/Presentation/ProductsFeature/Sources/.../Views/ProductDetailView.swift`（修改，增加朗读按钮）
- `Packages/Presentation/ProductsFeature/Sources/.../ViewModels/ProductDetailViewModel.swift`（修改）
- `Packages/Presentation/BasketFeature/Sources/.../Views/BasketView.swift`（修改，增加摘要播报按钮）
- `Packages/Presentation/BasketFeature/.../ViewModels/BasketViewModel.swift`（修改）
- `MyEcommerceApp/MyEcommerceApp.swift`（修改，追加注册）

## 验收标准

- [ ] 点击朗读按钮后能正常播报商品信息
- [ ] 播报文案口语化、自然，包含名称、价格等关键信息
- [ ] 音色可配置（默认使用女性声音）
- [ ] 播报中可以点击按钮停止
- [ ] 页面离开时语音自动停止，无内存泄漏
- [ ] 购物车摘要播报正确（如果实现）

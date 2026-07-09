import ProductAbstraction
import SpeechAbstraction

import RxSwift

@MainActor
public final class SpeakProductDetailUseCase: SpeakProductDetailUseCaseProtocol {

    private let speechSynthesizer: SpeechSynthesizerProtocol
    private let disposeBag = DisposeBag()

    public init(speechSynthesizer: SpeechSynthesizerProtocol) {
        self.speechSynthesizer = speechSynthesizer
    }

    public func speak(product: ProductDomainModelProtocol) -> Observable<SpeechPlaybackStatus> {
        let script = buildScript(for: product)
        return speechSynthesizer.speak(text: script, voice: .defaultFemale)
    }

    public func stopSpeaking() {
        speechSynthesizer.stopSpeaking()
    }

    // MARK: - Script Builder

    private func buildScript(for product: ProductDomainModelProtocol) -> String {
        var parts: [String] = []

        parts.append("这是「\(product.name)」")

        let price = String(format: "%.2f", product.price)
        parts.append("价格 \(price) 元")

        if product.quantity > 10 {
            parts.append("目前库存充足")
        } else if product.quantity > 0 {
            parts.append("仅剩 \(product.quantity) 件")
        } else {
            parts.append("暂时缺货")
        }

        return parts.joined(separator: "，")
    }
}

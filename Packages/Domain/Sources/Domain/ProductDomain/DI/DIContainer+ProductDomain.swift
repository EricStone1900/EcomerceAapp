import ProductAbstraction
import DIAbstraction
import SpeechAbstraction

import RxSwift

extension DIContainer {

    @MainActor
    public static func registerGetProductsUseCase() {

        DIContainer.shared.register(GetProductsUseCaseProtocol.self) { _ in

            let repo = DIContainer.shared.resolve(ProductRepositoryProtocol.self)

            return GetProductsUseCase(productRepository: repo!)
        }
    }

    @MainActor
    public static func registerVoiceSearchUseCase() {
        DIContainer.shared.register(VoiceSearchProductsUseCaseProtocol.self) { resolver in
            VoiceSearchProductsUseCase(
                speechRecognizer: resolver.resolve(SpeechRecognizerProtocol.self)!,
                productRepository: resolver.resolve(ProductRepositoryProtocol.self)!
            )
        }
    }

    @MainActor
    public static func registerSpeakProductUseCase() {
        DIContainer.shared.register(SpeakProductDetailUseCaseProtocol.self) { resolver in
            SpeakProductDetailUseCase(
                speechSynthesizer: resolver.resolve(SpeechSynthesizerProtocol.self)!
            )
        }
    }
}

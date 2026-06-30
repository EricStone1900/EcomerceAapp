import Foundation
import RxSwift

public protocol LoadWebContentUseCaseProtocol {
    func execute(content: WebContent) -> Observable<WebLoadInstruction>
}

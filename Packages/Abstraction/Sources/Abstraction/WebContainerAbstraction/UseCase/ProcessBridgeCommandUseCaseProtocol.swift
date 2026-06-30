import Foundation
import RxSwift

public protocol ProcessBridgeCommandUseCaseProtocol {
    func execute(command: WebBridgeCommand) -> Observable<NativeBridgeAction>
}

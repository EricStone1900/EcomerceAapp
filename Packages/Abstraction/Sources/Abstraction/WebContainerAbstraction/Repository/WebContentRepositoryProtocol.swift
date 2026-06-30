import Foundation
import RxSwift

public protocol WebContentRepositoryProtocol {
    /// 将 WebContent 解析为 WKWebView 可直接执行的加载指令。
    func resolveInstruction(for content: WebContent) -> Observable<WebLoadInstruction>
}

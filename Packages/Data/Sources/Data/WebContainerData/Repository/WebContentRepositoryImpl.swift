import Foundation
import RxSwift

import WebContainerAbstraction

public final class WebContentRepositoryImpl: WebContentRepositoryProtocol {
    private let localSource: LocalHTMLDataSource
    private let remoteSource: RemoteWebDataSource

    public init(
        localSource: LocalHTMLDataSource = .init(),
        remoteSource: RemoteWebDataSource = .init()
    ) {
        self.localSource = localSource
        self.remoteSource = remoteSource
    }

    public func resolveInstruction(for content: WebContent) -> Observable<WebLoadInstruction> {
        Observable.create { observer in
            do {
                let instruction: WebLoadInstruction
                switch content {
                case .remoteURL(let url):
                    let request = self.remoteSource.buildRequest(for: url)
                    instruction = .loadRequest(request)
                case .localFile(let name, let bundle):
                    let (fileURL, accessURL) = try self.localSource.resolve(
                        fileName: name, bundle: bundle
                    )
                    instruction = .loadFile(fileURL: fileURL, accessURL: accessURL)
                case .htmlString(let html, let baseURL):
                    instruction = .loadHTML(html: html, baseURL: baseURL)
                }
                observer.onNext(instruction)
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }
}

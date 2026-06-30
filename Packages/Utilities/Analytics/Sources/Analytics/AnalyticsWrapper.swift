import Foundation
import RxSwift
import API

import AnalyticsAbstraction

final class AnalyticsWrapper: AnalyticsWrapperProtocol {

    private let apiProvider: APIProviderProtocol
    private let disposeBag = DisposeBag()

    init(apiProvider: APIProviderProtocol = APIProvider()) {
        self.apiProvider = apiProvider
    }

    func trackEvent(_ event: String) {
        apiProvider
            .perform(AnalyticsAPI.trackEvent(event: event))
            .subscribe(
                onNext: { _ in
                    print("Analytics event sent: \(event)")
                },
                onError: { error in
                    print("Analytics event failed: \(error.localizedDescription)")
                }
            )
            .disposed(by: disposeBag)
    }

}

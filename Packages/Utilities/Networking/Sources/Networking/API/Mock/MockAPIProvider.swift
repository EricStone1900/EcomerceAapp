import Foundation
import RxSwift

public final class MockAPIProvider: APIProviderProtocol {

    private let delay: DispatchTimeInterval

    private let shouldFail: Bool

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }()

    public init(delay: DispatchTimeInterval = .milliseconds(300), shouldFail: Bool = false) {
        self.delay = delay
        self.shouldFail = shouldFail
    }

    public func perform(_ request: APIRequestProtocol) -> Observable<APIResponse> {
        if shouldFail {
            return Observable.error(APIError.invalidServerResponse)
        }

        let responseData: Data

        switch request.path {
        case "/products":
            responseData = try! encoder.encode(MockDataFactory.products)

        case "/users":
            let user = MockUser(
                id: UUID(),
                userName: "MockUser_\(UUID().uuidString.prefix(8))"
            )
            responseData = try! encoder.encode(user)

        case let path where path.hasPrefix("/basket/add"):
            responseData = Data()

        case let path where path.hasPrefix("/basket/view/"):
            responseData = try! encoder.encode(MockDataFactory.basketItems)

        case "/analytics/event":
            responseData = Data()

        default:
            return Observable.error(APIError.invalidURL)
        }

        return Observable<Int>
            .timer(delay, scheduler: MainScheduler.instance)
            .map { _ in
                APIResponse(statusCode: 200, data: responseData)
            }
    }
}

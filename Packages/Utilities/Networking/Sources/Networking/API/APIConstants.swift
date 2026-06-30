import Foundation

enum APIConstants {

    static var host: String {
        switch EnvironmentManager.current {
        case .dev: return "localhost"
        case .prd: return "api.myecoapp.com"
        }
    }

    static var scheme: String {
        switch EnvironmentManager.current {
        case .dev: return "http"
        case .prd: return "https"
        }
    }

    static var port: Int {
        switch EnvironmentManager.current {
        case .dev: return 8080
        case .prd: return 443
        }
    }
}

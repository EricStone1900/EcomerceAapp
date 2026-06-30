import Foundation

public enum EnvironmentManager {

    public static let current: AppEnvironment = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-environment") {
            if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-environment"),
               idx + 1 < ProcessInfo.processInfo.arguments.count {
                return AppEnvironment(rawValue: ProcessInfo.processInfo.arguments[idx + 1]) ?? .dev
            }
        }
        return .dev
        #else
        return .prd
        #endif
    }()
}

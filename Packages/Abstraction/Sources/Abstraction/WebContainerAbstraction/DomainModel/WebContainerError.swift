import Foundation

/// WebContainer 相关的错误类型。
public enum WebContainerError: LocalizedError {
    case localFileNotFound(String)
    case invalidURL
    case bridgeMessageParseFailed

    public var errorDescription: String? {
        switch self {
        case .localFileNotFound(let fileName):
            return "Local file not found: \(fileName)"
        case .invalidURL:
            return "Invalid URL"
        case .bridgeMessageParseFailed:
            return "Failed to parse bridge message"
        }
    }
}

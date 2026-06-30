import Foundation

/// 加载目标描述，覆盖三种场景，Use Case 统一消费。
public enum WebContent {
    case remoteURL(URL)
    case localFile(fileName: String, bundle: Bundle = .main)
    case htmlString(String, baseURL: URL?)
}

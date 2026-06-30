import Foundation

/// Use Case 的输出，对应 WKWebView 的三种加载方式。
/// 保持 Domain 层对 WebKit 的隔离。
public enum WebLoadInstruction {
    case loadRequest(URLRequest)
    case loadFile(fileURL: URL, accessURL: URL)
    case loadHTML(html: String, baseURL: URL?)
}

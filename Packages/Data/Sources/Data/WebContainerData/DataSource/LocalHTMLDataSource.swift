import Foundation

import WebContainerAbstraction

public struct LocalHTMLDataSource {

    public init() {}

    /// 返回 (fileURL, accessURL) — WKWebView 的双路径需求。
    public func resolve(fileName: String, bundle: Bundle) throws -> (fileURL: URL, accessURL: URL) {
        let nameOnly = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.isEmpty ? "html"
                  : (fileName as NSString).pathExtension

        guard let fileURL = bundle.url(forResource: nameOnly, withExtension: ext) else {
            throw WebContainerError.localFileNotFound(fileName)
        }

        let accessURL = fileURL.deletingLastPathComponent()
        return (fileURL, accessURL)
    }
}

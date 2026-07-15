import Foundation
import Testing

@testable import CameraML

/// `YOLOPlugin` 需要一个真实的编译好的 CoreML 模型才能构造成功，本仓库没有携带这样的资产
/// （见 YOLOPlugin.swift 顶部注释），所以这里只测得到"资源缺失/不合法时优雅抛错、不崩溃"这条
/// 路径——这是本包在没有真实模型资产的前提下唯一能诚实验证的行为，不去伪造一次推理结果。
@Suite("YOLOPlugin construction failure paths")
struct YOLOPluginTests {

    @Test("throws when the model file doesn't exist")
    func throwsWhenModelFileMissing() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mlmodelc")

        #expect(throws: (any Error).self) {
            try YOLOPlugin(modelURL: missingURL)
        }
    }

    @Test("throws when the file exists but isn't a valid compiled model")
    func throwsWhenFileIsNotAValidModel() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mlmodelc")
        try "not a real model".write(to: url, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) {
            try YOLOPlugin(modelURL: url)
        }
    }
}

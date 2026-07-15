@preconcurrency import CoreML
import CoreVideo
import Foundation

import CameraPipeline

/// 示例实现：验证"新增一个 CoreML 模型仅需新类型 + 组合根注册一行"这条 Stage 4 验收标准。
///
/// `CameraML` 这个包本身不携带任何真实模型资产——训练好的 `.mlmodelc` 通常几十上百 MB，不适合
/// 提交进代码仓库，也不是凭空能生成的东西；真实资产应该由使用这个插件的 App 提供（打进 App
/// target 的 Bundle，或运行时下载）。所以 `modelURL` 是必传参数，不像计划文档设想的那样从
/// `Bundle.module` 找（这个包没有声明任何 `resources:`，`Bundle.module` 根本不存在），
/// 构造失败（文件不存在/不是合法模型）时让 `MLModel(contentsOf:)` 自己的 throw 直接传出去，
/// 在 App 组合根装配阶段就能被发现和处理（跳过注册/记日志），而不是让 App 在拍照过程中因为
/// 一次 lazy var 访问直接崩溃。
///
/// `MLModel` 不是 Sendable（Apple 没标注），处理方式跟本代码库对 Metal/CoreImage 类型的一贯做法
/// 一致：`@unchecked Sendable`——模型加载完之后只读，不存在并发修改的场景。
public final class YOLOPlugin: MLModelPlugin, @unchecked Sendable {

    public let id = PluginID("yolo")
    public let preferredFPS = 6
    public let model: MLModel

    public init(modelURL: URL) throws {
        model = try MLModel(contentsOf: modelURL)
    }

    public func preprocess(_ frame: Frame) -> CVPixelBuffer {
        frame.pixelBuffer
    }

    public func postprocess(_ output: MLFeatureProvider) -> [Annotation] {
        // 解析 YOLO 输出层（anchor box 解码 + NMS）-> [DetectedObject] -> .objects(...)，
        // 具体解析逻辑依赖选用的模型的输出格式，留到真的接入一个具体模型时再写——这是"有真实
        // 数据源但没写解析逻辑"的占位（跟 HistogramAnalyzer 在 Stage 2 时的处境一样），
        // 不是伪造检测结果。
        [.objects([])]
    }

    public func analyze(_ frame: Frame) async -> [Annotation] {
        // 动态读模型自己声明的输入 feature 名字，而不是硬编码猜一个（比如 "image"）——
        // 不同模型的输入名不一样，这样写才是对"任意一个真实 CoreML 视觉模型"都成立的通用代码，
        // 不是针对某个特定模型调好的一次性脚本。
        guard let inputName = model.modelDescription.inputDescriptionsByName.keys.first else { return [] }
        let featureValue = MLFeatureValue(pixelBuffer: preprocess(frame))
        guard
            let provider = try? MLDictionaryFeatureProvider(dictionary: [inputName: featureValue]),
            let output = try? await model.prediction(from: provider)
        else {
            return []
        }
        return postprocess(output)
    }
}

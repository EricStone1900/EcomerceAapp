import CoreML

import CameraPipeline

/// `FrameAnalyzer` 的一个特化：显式声明依赖一个 CoreML 模型，把"预处理 Frame -> 模型输入"和
/// "模型输出 -> Annotation"这两步拆开，方便不同模型复用同一套接入 `PipelineController` 的骨架。
public protocol MLModelPlugin: FrameAnalyzer {
    associatedtype Input
    associatedtype Output
    var model: MLModel { get }
    func preprocess(_ frame: Frame) -> Input
    func postprocess(_ output: Output) -> [Annotation]
}

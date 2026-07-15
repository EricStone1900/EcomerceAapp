import CoreImage
import Foundation
@preconcurrency import Metal

import CameraCore
import CameraFeature
import CameraFilters
import CameraML
import CameraPipeline
import CameraVision

/// App 是唯一同时 import 全部 Camera 包的地方，跟仓库现有 `AppRouteFactoryRegistrar` /
/// `AppWebRouteFactory` 同一模式：协议在低层包定义，插件实现分散在 CameraVision/CameraML/
/// CameraFilters，装配只发生在这里。`CameraFeature` 编译期完全不知道这三个插件包的存在，
/// 新增一个插件只需要"新类型 + 这里注册一行"，是 Stage 4"L1/L2/L4 零改动扩展插件"这条
/// 验收标准真正落地的地方。
///
/// `CameraFeatureContext`/`ThermalObserver` 的类型定义本身住在 `CameraFeature` 包里
/// （见 `CameraFeatureContext.swift`）——这里只负责"用哪些具体插件类型来装配"，这样
/// `CameraUI.CameraViewModel` 才能单纯 `import CameraFeature` 拿到 `CameraFeatureContext`
/// 这个契约类型，不需要反过来依赖 `CameraVision`/`CameraML`/`CameraFilters`。
enum AppCameraComposition {

    @MainActor
    static func makeCameraFeature() -> CameraFeatureContext {
        let registry = PluginRegistry()
        registerAnalyzers(into: registry)
        registerProcessors(into: registry)

        let camera = CameraSession()
        let pipeline = PipelineController()
        let thermalPolicyUseCase = ThermalPolicyUseCase(pipeline: pipeline)
        let thermalObserver = ThermalObserver(thermalPolicyUseCase: thermalPolicyUseCase)
        thermalObserver.start()

        return CameraFeatureContext(
            session: camera,
            pipeline: pipeline,
            registry: registry,
            presetUseCase: PresetUseCase(cameraSource: camera, pipeline: pipeline, registry: registry),
            thermalPolicyUseCase: thermalPolicyUseCase,
            documentCaptureUseCase: DocumentCaptureUseCase(cameraSource: camera, pipeline: pipeline),
            thermalObserver: thermalObserver
        )
    }

    /// CameraVision 的分析器全部是 Vision framework 内建能力，不依赖任何外部资产文件，
    /// 可以无条件注册。
    private static func registerAnalyzers(into registry: PluginRegistry) {
        registry.register(DocumentAnalyzer(), id: PluginID("document"))
        registry.register(CardAnalyzer(), id: PluginID("card"))
        registry.register(FaceAnalyzer(), id: PluginID("face"))
        registry.register(RectangleAnalyzer(), id: PluginID("rectangle"))
        registry.register(BarcodeAnalyzer(), id: PluginID("barcode"))
        registry.register(OCRAnalyzer(), id: PluginID("ocr"))
        registry.register(HorizonAnalyzer(), id: PluginID("horizon"))
        registry.register(HistogramAnalyzer(), id: PluginID("histogram"))

        // YOLOPlugin 需要一个真实的编译好的 CoreML 模型，本仓库没有随包携带这样的资产
        // （训练好的模型文件通常几十上百 MB，不适合提交进代码仓库）——尝试从 App bundle 加载，
        // 找不到就跳过注册并打日志，不让整个组合根因为一个可选插件缺资产而失败。
        // 真机验收前需要手动把一个真实的 YOLO.mlmodelc 加进 Xcode target 的 Bundle Resources。
        if let modelURL = Bundle.main.url(forResource: "YOLO", withExtension: "mlmodelc") {
            do {
                registry.register(try YOLOPlugin(modelURL: modelURL), id: PluginID("yolo"))
            } catch {
                print("⚠️ AppCameraComposition: failed to load YOLO model, skipping registration: \(error)")
            }
        } else {
            print("⚠️ AppCameraComposition: YOLO.mlmodelc not found in bundle, skipping YOLOPlugin registration")
        }
    }

    private static func registerProcessors(into registry: PluginRegistry) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("⚠️ AppCameraComposition: no Metal device available, skipping all FrameProcessor registration")
            return
        }
        let ciContext = CIContext(mtlDevice: device)

        registry.register(BeautyProcessor(ciContext: ciContext), id: PluginID("beauty"))

        // LUTProcessor 需要一个真实的 .cube 文件，本仓库同样没有随包携带——尝试从 App bundle
        // 加载，找不到就跳过注册并打日志。真机验收前需要手动把一个真实的 Food.cube 加进
        // Xcode target 的 Bundle Resources（.cube 是纯文本格式，体积很小，随时可以补）。
        if let cubeURL = Bundle.main.url(forResource: "Food", withExtension: "cube") {
            do {
                let lutProcessor = try LUTProcessor(id: PluginID("lut.food"), cubeFileURL: cubeURL, ciContext: ciContext)
                registry.register(lutProcessor, id: PluginID("lut.food"))
            } catch {
                print("⚠️ AppCameraComposition: failed to parse Food.cube, skipping registration: \(error)")
            }
        } else {
            print("⚠️ AppCameraComposition: Food.cube not found in bundle, skipping LUTProcessor registration")
        }
    }
}

import CameraCore
import Shared

/// Preset 里的手动参数，`nil` 字段代表"不覆盖，保持自动"。
public struct ManualSettings: Codable, Sendable, Equatable {
    public var iso: Float?
    public var shutterSeconds: Double?
    public var exposureBias: Float?

    public init(iso: Float? = nil, shutterSeconds: Double? = nil, exposureBias: Float? = nil) {
        self.iso = iso
        self.shutterSeconds = shutterSeconds
        self.exposureBias = exposureBias
    }
}

public enum CaptureFormat: String, Codable, Sendable {
    case raw, heif, rawPlusHeif
}

/// 跨镜头可复用的一组相机参数 + 插件配置。`processorIDs`/`analyzerIDs` 只存 `PluginID.rawValue`，
/// 不存插件实例——实例由 `PluginRegistry` 持有，`PresetUseCase.apply` 时按 ID 查表解析，这样
/// `CameraPreset` 才能是纯数据、可以直接 `Codable` 持久化，不需要关心具体插件类型。
public struct CameraPreset: Codable, Sendable, Equatable {
    public var name: String
    public var lens: LensType
    public var manual: ManualSettings?
    public var processorIDs: [String]
    public var analyzerIDs: [String]
    public var captureFormat: CaptureFormat

    public init(
        name: String, lens: LensType, manual: ManualSettings?,
        processorIDs: [String], analyzerIDs: [String], captureFormat: CaptureFormat
    ) {
        self.name = name
        self.lens = lens
        self.manual = manual
        self.processorIDs = processorIDs
        self.analyzerIDs = analyzerIDs
        self.captureFormat = captureFormat
    }

    public static let document = CameraPreset(
        name: "Document", lens: .wide, manual: nil,
        processorIDs: [], analyzerIDs: ["document"], captureFormat: .rawPlusHeif
    )
    public static let portrait = CameraPreset(
        name: "Portrait", lens: .wide, manual: nil,
        processorIDs: ["beauty"], analyzerIDs: ["face"], captureFormat: .heif
    )
    public static let food = CameraPreset(
        name: "Food", lens: .wide, manual: ManualSettings(exposureBias: 0.3),
        processorIDs: ["lut.food"], analyzerIDs: [], captureFormat: .heif
    )
    public static let night = CameraPreset(
        name: "Night", lens: .wide, manual: ManualSettings(iso: 1600),
        processorIDs: [], analyzerIDs: [], captureFormat: .rawPlusHeif
    )
}

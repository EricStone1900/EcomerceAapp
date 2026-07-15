import AVFoundation
import SwiftUI

import CameraCore
import CameraFeature
import DesignSystem
import Shared

/// 正式相机页面：订阅 `CameraViewModel.state`（`CameraViewState`）、通过
/// `viewModel.send(_:CameraAction)` 发送用户操作，单向数据流——不直接触碰 `CameraSession`/
/// `PipelineController` 这些底层类型（那是 `CameraViewModel` 的职责）。
///
/// `state` 在第一次 `DeviceCapability` 到达前是 `nil`（没有可以诚实填充的默认曝光范围），
/// 这段时间显示一个加载态而不是假装有一份能用的手动控制面板。
public struct CameraView: View {

    @StateObject private var viewModel: CameraViewModel

    public init(context: CameraFeatureContext) {
        _viewModel = StateObject(wrappedValue: CameraViewModel(context: context))
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let state = viewModel.state {
                    switch state.previewMode {
                    case .passthrough:
                        if let previewLayer = viewModel.previewLayer {
                            PassthroughPreviewContainer(previewLayer: previewLayer)
                        } else {
                            Color.black
                        }
                    case .processed:
                        ProcessedPreviewContainer(renderedFrames: viewModel.renderedFrames)
                    }
                    OverlayCanvas(annotations: state.annotations, showsGrid: false, showsLevel: false)
                } else {
                    Color.black
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            if let state = viewModel.state {
                CameraControlPanel(state: state) { action in
                    Task { await viewModel.send(action) }
                }
            }
        }
        .background(Color.black)
        .task {
            await viewModel.start()
        }
    }
}

/// 底部手动控制面板：镜头切换、Preset 选择、ISO/EV 滑杆、拍照按钮。拆成独立子视图是为了让
/// `CameraView.body` 在 `state` 变化时只需要重新求值这一小块，不用重新构建整个预览层级。
private struct CameraControlPanel: View {

    let state: CameraViewState
    let send: (CameraAction) -> Void

    var body: some View {
        VStack(spacing: .spacingM) {
            Picker(
                "Lens",
                selection: Binding(
                    get: { state.capability.lens },
                    set: { send(.switchLens($0)) }
                )
            ) {
                ForEach(LensType.allCases, id: \.self) { lens in
                    Text(lens.rawValue.capitalized).tag(lens)
                }
            }
            .pickerStyle(.segmented)

            Picker(
                "Preset",
                selection: Binding<PresetID?>(
                    get: { state.activePreset },
                    set: { newValue in
                        guard let newValue else { return }
                        send(.applyPreset(newValue))
                    }
                )
            ) {
                Text("Manual").tag(PresetID?.none)
                ForEach([CameraPreset.document, .portrait, .food, .night], id: \.name) { preset in
                    Text(preset.name).tag(PresetID?.some(preset.name))
                }
            }
            .pickerStyle(.menu)

            isoSlider
            evSlider

            Button {
                send(.capture)
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.appTextSecondary, lineWidth: 2))
            }
            .accessibilityLabel("Capture photo")
        }
        .designPadding(.l)
        .background(Color.appBackground)
    }

    private var isoSlider: some View {
        let range = state.capability.isoRange
        return VStack(alignment: .leading, spacing: .spacingXs) {
            Text("ISO: \(Int(state.manual.iso ?? range.lowerBound))")
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Slider(
                value: Binding(
                    get: { Double(state.manual.iso ?? range.lowerBound) },
                    set: { send(.setISO(Float($0))) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
        }
    }

    private var evSlider: some View {
        let range = state.capability.evRange
        return VStack(alignment: .leading, spacing: .spacingXs) {
            Text(String(format: "EV: %.1f", state.manual.exposureBias ?? 0))
                .font(.appCaption)
                .foregroundColor(.appTextSecondary)
            Slider(
                value: Binding(
                    get: { Double(state.manual.exposureBias ?? 0) },
                    set: { send(.setEV(Float($0))) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
        }
    }
}

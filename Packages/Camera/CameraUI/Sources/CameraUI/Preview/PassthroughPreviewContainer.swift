import AVFoundation
import SwiftUI

/// L4 展示层里唯一的 UIKit 接触点之一（本 stage 版本）。
/// 只依赖 CameraCore 暴露的 AVCaptureVideoPreviewLayer，不 import 任何插件包。
public struct PassthroughPreviewContainer: UIViewRepresentable {

    let previewLayer: AVCaptureVideoPreviewLayer

    public init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
    }

    public func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        return view
    }

    public func updateUIView(_ uiView: PreviewHostView, context: Context) {
        uiView.previewLayer = previewLayer
    }

    /// SwiftUI 的 updateUIView 不保证在 Auto Layout 把 wrapper view 的最终尺寸解析出来之后
    /// 再次被调用——previewLayer 是手动 addSublayer 上去的子 layer，不受 Auto Layout 管理，
    /// 若只在 updateUIView 里赋一次 frame，很容易停在初始的 CGRect.zero（session 明明在跑，
    /// 但 layer 尺寸是 0x0，画面自然是黑的）。用 layoutSubviews 兜底，保证每次真实布局变化
    /// （包括第一次）previewLayer.frame 都会同步刷新。
    public final class PreviewHostView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        public override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

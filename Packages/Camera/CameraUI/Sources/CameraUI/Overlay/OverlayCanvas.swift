import SwiftUI

import CameraPipeline

/// SwiftUI 端仅是 ForEach + Canvas 按类型画图，新增 Annotation 类型只需加一个绘制 case，
/// 不需要 UI 知道数据从哪来。本 stage 先接入 Grid / Level / Histogram 三种。
public struct OverlayCanvas: View {

    let annotations: [ScreenAnnotation]
    let showsGrid: Bool
    let showsLevel: Bool

    public init(annotations: [ScreenAnnotation], showsGrid: Bool, showsLevel: Bool) {
        self.annotations = annotations
        self.showsGrid = showsGrid
        self.showsLevel = showsLevel
    }

    public var body: some View {
        Canvas { context, size in
            if showsGrid {
                drawGrid(context: &context, size: size)
            }
            for annotation in annotations {
                draw(annotation, context: &context, size: size)
            }
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let columnStep = size.width / 3
        let rowStep = size.height / 3
        for index in 1...2 {
            path.move(to: CGPoint(x: columnStep * CGFloat(index), y: 0))
            path.addLine(to: CGPoint(x: columnStep * CGFloat(index), y: size.height))
            path.move(to: CGPoint(x: 0, y: rowStep * CGFloat(index)))
            path.addLine(to: CGPoint(x: size.width, y: rowStep * CGFloat(index)))
        }
        context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1)
    }

    private func draw(_ annotation: ScreenAnnotation, context: inout GraphicsContext, size: CGSize) {
        switch annotation {
        case .histogram(let data):
            drawHistogram(data, context: &context, size: size)
        case .horizon(let angle):
            drawHorizon(angle: angle, context: &context, size: size)
        case .quad(let corners):
            drawQuad(corners: corners, context: &context)
        case .objects(let boxes):
            for box in boxes {
                context.stroke(Path(box), with: .color(.yellow), lineWidth: 2)
            }
        }
    }

    private func drawHorizon(angle: Double, context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let length = max(size.width, size.height)
        let radians = angle * .pi / 180
        let dx = CGFloat(cos(radians)) * length
        let dy = CGFloat(sin(radians)) * length
        path.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
        path.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
        context.stroke(path, with: .color(.green), lineWidth: 2)
    }

    private func drawQuad(corners: [CGPoint], context: inout GraphicsContext) {
        guard corners.count == 4 else { return }
        var path = Path()
        path.move(to: corners[0])
        for corner in corners.dropFirst() {
            path.addLine(to: corner)
        }
        path.closeSubpath()
        context.stroke(path, with: .color(.red), lineWidth: 2)
    }

    /// HistogramData 的四条曲线画在屏幕底部一个半透明面板里，bucket 值已经在 HistogramAnalyzer
    /// 里按各自通道的最大值归一化到 [0, 1]，这里只管映射到面板高度，不用再关心原始计数量级。
    private func drawHistogram(_ data: HistogramData, context: inout GraphicsContext, size: CGSize) {
        let panelHeight: CGFloat = 80
        let panelRect = CGRect(x: 0, y: size.height - panelHeight, width: size.width, height: panelHeight)
        context.fill(Path(panelRect), with: .color(.black.opacity(0.35)))
        drawHistogramCurve(data.luminanceBuckets, color: .white.opacity(0.9), in: panelRect, context: &context)
        drawHistogramCurve(data.redBuckets, color: .red.opacity(0.7), in: panelRect, context: &context)
        drawHistogramCurve(data.greenBuckets, color: .green.opacity(0.7), in: panelRect, context: &context)
        drawHistogramCurve(data.blueBuckets, color: .blue.opacity(0.7), in: panelRect, context: &context)
    }

    private func drawHistogramCurve(
        _ buckets: [Float], color: Color, in rect: CGRect, context: inout GraphicsContext
    ) {
        guard buckets.count > 1 else { return }
        var path = Path()
        let stepX = rect.width / CGFloat(buckets.count - 1)
        for (index, value) in buckets.enumerated() {
            let point = CGPoint(x: rect.minX + CGFloat(index) * stepX, y: rect.maxY - CGFloat(value) * rect.height)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}

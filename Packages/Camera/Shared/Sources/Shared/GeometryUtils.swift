import CoreGraphics

public enum GeometryUtils {

    /// 四边形透视校正矩阵：把检测到的四个角点映射到 targetSize 的矩形。
    ///
    /// `CGAffineTransform` 只有 6 自由度（仿射：旋转/缩放/错切/平移），无法表达真正的透视投影
    /// （8 自由度的单应矩阵）。这里用 corners 里的 topLeft/topRight/bottomLeft 三个点精确求解仿射
    /// 变换作为近似——三点对应正好等于仿射变换的自由度数，第四个角点（bottomRight）映射后会有
    /// 残余误差，这是文档里"手写 3x3 单应矩阵求解后取仿射近似"的具体实现方式。
    /// corners 顺序固定为 [topLeft, topRight, bottomRight, bottomLeft]，与 Vision 的
    /// VNRectangleObservation 顺序一致。
    public static func perspectiveTransform(quad corners: [CGPoint], targetSize: CGSize) -> CGAffineTransform {
        precondition(corners.count == 4, "quad must have exactly 4 corners")

        let topLeft = corners[0]
        let topRight = corners[1]
        let bottomLeft = corners[3]

        // 解两个线性方程组：a*x + c*y + tx = x'，b*x + d*y + ty = y'，
        // 用同一个系数矩阵 M 对 (x', y') 两列分别求解。
        let m = Matrix3x3(
            row0: (topLeft.x, topLeft.y, 1),
            row1: (topRight.x, topRight.y, 1),
            row2: (bottomLeft.x, bottomLeft.y, 1)
        )
        guard let inverse = m.inverse() else {
            // 退化四边形（三点共线）时退回单位变换，调用方自行判断是否要重试检测。
            return .identity
        }

        let (a, c, tx) = inverse.multiply(by: (0, targetSize.width, 0))
        let (b, d, ty) = inverse.multiply(by: (0, 0, targetSize.height))

        return CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }

    /// EMA 低通滤波，用于检测框时域平滑，消除逐帧抖动。
    public struct EMAFilter {
        private var value: CGPoint?
        public let alpha: CGFloat

        public init(alpha: CGFloat = 0.3) {
            self.alpha = alpha
        }

        public mutating func update(_ newValue: CGPoint) -> CGPoint {
            guard let previous = value else {
                value = newValue
                return newValue
            }
            let smoothed = CGPoint(
                x: previous.x + alpha * (newValue.x - previous.x),
                y: previous.y + alpha * (newValue.y - previous.y)
            )
            value = smoothed
            return smoothed
        }
    }

    /// 四个角点各自维护一个 EMAFilter，避免相邻帧检测框跳变。
    public struct QuadEMAFilter {
        private var filters: [EMAFilter]

        public init(alpha: CGFloat = 0.3) {
            filters = Array(repeating: EMAFilter(alpha: alpha), count: 4)
        }

        public mutating func update(_ corners: [CGPoint]) -> [CGPoint] {
            precondition(corners.count == 4)
            return zip(filters.indices, corners).map { index, point in filters[index].update(point) }
        }
    }
}

/// perspectiveTransform 内部使用的 3x3 矩阵求逆辅助类型，不对外暴露。
private struct Matrix3x3 {
    let row0: (CGFloat, CGFloat, CGFloat)
    let row1: (CGFloat, CGFloat, CGFloat)
    let row2: (CGFloat, CGFloat, CGFloat)

    var determinant: CGFloat {
        row0.0 * (row1.1 * row2.2 - row1.2 * row2.1)
            - row0.1 * (row1.0 * row2.2 - row1.2 * row2.0)
            + row0.2 * (row1.0 * row2.1 - row1.1 * row2.0)
    }

    func inverse() -> Matrix3x3? {
        let det = determinant
        guard abs(det) > .ulpOfOne else { return nil }

        let (a, b, c) = row0
        let (d, e, f) = row1
        let (g, h, i) = row2

        let cofactor00 = e * i - f * h
        let cofactor01 = -(d * i - f * g)
        let cofactor02 = d * h - e * g
        let cofactor10 = -(b * i - c * h)
        let cofactor11 = a * i - c * g
        let cofactor12 = -(a * h - b * g)
        let cofactor20 = b * f - c * e
        let cofactor21 = -(a * f - c * d)
        let cofactor22 = a * e - b * d

        // 逆矩阵 = 伴随矩阵（余子式矩阵的转置）/ 行列式。
        return Matrix3x3(
            row0: (cofactor00 / det, cofactor10 / det, cofactor20 / det),
            row1: (cofactor01 / det, cofactor11 / det, cofactor21 / det),
            row2: (cofactor02 / det, cofactor12 / det, cofactor22 / det)
        )
    }

    func multiply(by vector: (CGFloat, CGFloat, CGFloat)) -> (CGFloat, CGFloat, CGFloat) {
        (
            row0.0 * vector.0 + row0.1 * vector.1 + row0.2 * vector.2,
            row1.0 * vector.0 + row1.1 * vector.1 + row1.2 * vector.2,
            row2.0 * vector.0 + row2.1 * vector.1 + row2.2 * vector.2
        )
    }
}

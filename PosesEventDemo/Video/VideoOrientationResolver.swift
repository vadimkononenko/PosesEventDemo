import CoreGraphics
import ImageIO

/// Converts the rotation stored in a video track into an image orientation.
nonisolated struct VideoOrientationResolver {
    func orientation(for transform: CGAffineTransform) -> CGImagePropertyOrientation? {
        switch (quantize(transform.a), quantize(transform.b), quantize(transform.c), quantize(transform.d)) {
        case (1, 0, 0, 1): .up
        case (-1, 0, 0, 1): .upMirrored
        case (-1, 0, 0, -1): .down
        case (1, 0, 0, -1): .downMirrored
        case (0, -1, 1, 0): .left
        case (0, 1, 1, 0): .leftMirrored
        case (0, 1, -1, 0): .right
        case (0, -1, -1, 0): .rightMirrored
        default: nil
        }
    }

    private func quantize(_ value: CGFloat) -> Int {
        if abs(value) < 0.01 { return 0 }
        return value > 0 ? 1 : -1
    }
}

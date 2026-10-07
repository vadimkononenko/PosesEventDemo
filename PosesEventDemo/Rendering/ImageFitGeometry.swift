import CoreGraphics

enum ImageFitGeometry {
    static func fittedRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else { return .zero }

        let scale = min(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale,
                          height: imageSize.height * scale)
        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
                             y: (containerSize.height - size.height) / 2)

        return CGRect(origin: origin, size: size)
    }

    static func viewPoint(for normalized: CGPoint, in fittedRect: CGRect) -> CGPoint {
        CGPoint(x: fittedRect.minX + normalized.x * fittedRect.width,
                y: fittedRect.minY + normalized.y * fittedRect.height)
    }
}

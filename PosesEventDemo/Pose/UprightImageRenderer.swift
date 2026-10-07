import CoreImage
import UIKit

/// Produces bitmaps whose pixels are already in display orientation.
///
/// A detector that receives such a bitmap with orientation `.up` has nothing to interpret:
/// the coordinates it returns are in the same space as what the user sees.
nonisolated enum UprightImageRenderer {
    /// Draws a photo with its EXIF orientation applied. Returns the original bitmap
    /// when the photo is already `.up`.
    static func render(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        let pixelSize = CGSize(width: image.size.width * image.scale,
                               height: image.size.height * image.scale)
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)

        // `draw(in:)` applies `imageOrientation`, so the result is upright.
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }.cgImage
    }

    /// Rotates a decoded video frame by its track orientation.
    static func render(_ image: CIImage,
                       orientation: CGImagePropertyOrientation,
                       context: CIContext) -> CGImage? {
        let oriented = image.oriented(orientation)
        let bounds = oriented.extent.integral
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        return context.createCGImage(oriented, from: bounds)
    }
}

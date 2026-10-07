import SwiftUI

/// Bounding boxes of people (Vision) over a video or an image shown with `.fit`.
struct PersonBoxOverlayView: View {
    let people: [PersonBox]
    let imageSize: CGSize
    var minConfidence: Float = 0

    var body: some View {
        Canvas { context, size in
            let fitted = ImageFitGeometry.fittedRect(imageSize: imageSize, in: size)
            guard !fitted.isEmpty else { return }

            for person in people where person.confidence >= minConfidence {
                let rect = CGRect(x: fitted.minX + person.rect.minX * fitted.width,
                                  y: fitted.minY + person.rect.minY * fitted.height,
                                  width: person.rect.width * fitted.width,
                                  height: person.rect.height * fitted.height)

                context.stroke(Path(roundedRect: rect, cornerRadius: 6),
                               with: .color(.white.opacity(0.9)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .allowsHitTesting(false)
    }
}

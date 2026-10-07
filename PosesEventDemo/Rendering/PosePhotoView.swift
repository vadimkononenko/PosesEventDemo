import SwiftUI

/// A photo with poses drawn over it. Fills the space it is given.
struct PosePhotoView: View {
    let image: UIImage
    let poses: [DetectedPose]
    var mode: OverlayMode = .skeleton
    var minConfidence: Float = 0
    var personColors: [Int: Int] = [:]
    var side: BodySide = .both

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.05)

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)

                PoseOverlayView(poses: poses,
                                imageSize: image.size,
                                mode: mode,
                                minConfidence: minConfidence,
                                personColors: personColors,
                                side: side)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

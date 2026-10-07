import SwiftUI

enum OverlayMode: String, CaseIterable, Identifiable {
    case points = "Points"
    case skeleton = "Skeleton"

    var id: String { rawValue }
}

/// Draws poses on top of an image that is shown with `.aspectRatio(contentMode: .fit)`.
/// The view must have the same size as the container of the image.
struct PoseOverlayView: View {
    let poses: [DetectedPose]
    let imageSize: CGSize
    /// Layers are independent: the skeleton (bones), the landmark dots, or both.
    var showsSkeleton = true
    var showsLandmarks = true
    var minConfidence: Float = 0
    /// Pose index -> color index of the person (see `PersonMatcher`), so the same person
    /// has the same color on every overlay. Without it, poses are colored in their order.
    var personColors: [Int: Int] = [:]
    /// Only one side of the body (plus the middle), for side views.
    var side: BodySide = .both

    init(poses: [DetectedPose],
         imageSize: CGSize,
         showsSkeleton: Bool = true,
         showsLandmarks: Bool = true,
         minConfidence: Float = 0,
         personColors: [Int: Int] = [:],
         side: BodySide = .both) {
        self.poses = poses
        self.imageSize = imageSize
        self.showsSkeleton = showsSkeleton
        self.showsLandmarks = showsLandmarks
        self.minConfidence = minConfidence
        self.personColors = personColors
        self.side = side
    }

    /// `.points`: only big dots. `.skeleton`: bones with small dots.
    init(poses: [DetectedPose],
         imageSize: CGSize,
         mode: OverlayMode,
         minConfidence: Float = 0,
         personColors: [Int: Int] = [:],
         side: BodySide = .both) {
        self.init(poses: poses,
                  imageSize: imageSize,
                  showsSkeleton: mode == .skeleton,
                  showsLandmarks: true,
                  minConfidence: minConfidence,
                  personColors: personColors,
                  side: side)
    }

    private static let palette: [Color] = [.green, .orange, .cyan, .pink, .yellow, .purple]

    /// Color of the person with this index, also used for legends next to the photo.
    static func color(forPerson index: Int) -> Color {
        palette[index % palette.count]
    }

    /// Landmarks below this value are drawn semi-transparent.
    private static let lowConfidence: Float = 0.5

    var body: some View {
        Canvas { context, size in
            let rect = ImageFitGeometry.fittedRect(imageSize: imageSize, in: size)
            guard !rect.isEmpty else { return }

            for (index, pose) in poses.enumerated() {
                let color = Self.color(forPerson: personColors[index] ?? index)
                draw(pose, color: color, in: rect, context: &context)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ pose: DetectedPose,
                      color: Color,
                      in rect: CGRect,
                      context: inout GraphicsContext) {
        // Points of the other side are dropped here, so their bones disappear too.
        let visible = pose.landmarks(minConfidence: minConfidence).filter { $0.joint.isVisible(for: side) }
        let byJoint = Dictionary(visible.map { ($0.joint, $0) },
                                 uniquingKeysWith: { first, _ in first })

        if showsSkeleton {
            // A bone is drawn only if both of its landmarks passed the threshold.
            for bone in Skeleton.bones {
                guard let from = byJoint[bone.from], let to = byJoint[bone.to] else { continue }

                var path = Path()
                path.move(to: point(for: from, in: rect))
                path.addLine(to: point(for: to, in: rect))

                let isWeak = min(from.confidence, to.confidence) < Self.lowConfidence
                context.stroke(path,
                               with: .color(color.opacity(isWeak ? 0.4 : 1)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }

        drawHands(of: pose, color: color, in: rect, context: &context)

        guard showsLandmarks else { return }

        // Small, so the photo stays visible under the skeleton.
        let radius: CGFloat = showsSkeleton ? 2.5 : 4
        for landmark in visible {
            let center = point(for: landmark, in: rect)
            let isWeak = landmark.confidence < Self.lowConfidence
            let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                             width: radius * 2, height: radius * 2))

            context.fill(dot, with: .color(color.opacity(isWeak ? 0.4 : 1)))
            context.stroke(dot, with: .color(.white.opacity(isWeak ? 0.4 : 1)), lineWidth: 0.75)
        }
    }

    /// Hands (Vision `detectsHands`): thinner than the body, they are small on the photo.
    /// The skeleton toggle controls the lines, the landmarks toggle controls the dots.
    private func drawHands(of pose: DetectedPose,
                           color: Color,
                           in rect: CGRect,
                           context: inout GraphicsContext) {
        for hand in pose.hands where side == .both || hand.side == side {
            let visible = hand.landmarks.filter { $0.confidence >= minConfidence }
            let byJoint = Dictionary(visible.map { ($0.joint, $0) }, uniquingKeysWith: { first, _ in first })

            if showsSkeleton {
                for bone in HandSkeleton.bones {
                    guard let from = byJoint[bone.from], let to = byJoint[bone.to] else { continue }

                    var path = Path()
                    path.move(to: ImageFitGeometry.viewPoint(for: from.position, in: rect))
                    path.addLine(to: ImageFitGeometry.viewPoint(for: to.position, in: rect))
                    context.stroke(path,
                                   with: .color(color.opacity(0.9)),
                                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }
            }

            if showsLandmarks {
                for landmark in visible {
                    let center = ImageFitGeometry.viewPoint(for: landmark.position, in: rect)
                    let dot = Path(ellipseIn: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3))
                    context.fill(dot, with: .color(.white))
                    context.stroke(dot, with: .color(color), lineWidth: 0.75)
                }
            }
        }
    }

    private func point(for landmark: PoseLandmark, in rect: CGRect) -> CGPoint {
        ImageFitGeometry.viewPoint(for: landmark.position, in: rect)
    }
}

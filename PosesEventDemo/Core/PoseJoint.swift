import Foundation

enum PoseJoint: String, CaseIterable, Codable, Hashable {
    // Head
    case nose
    case leftEyeInner, leftEye, leftEyeOuter        // inner/outer ML Kit
    case rightEyeInner, rightEye, rightEyeOuter
    case leftEar, rightEar
    case mouthLeft, mouthRight                      // ML Kit

    // Body
    case neck                                       // Vision
    case leftShoulder, rightShoulder
    case root                                       // Vision
    case leftHip, rightHip

    // Hands
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftPinky, rightPinky                      // ML Kit
    case leftIndex, rightIndex                      // ML Kit
    case leftThumb, rightThumb                      // ML Kit

    // Legs
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
    case leftHeel, rightHeel                        // ML Kit
    case leftFootIndex, rightFootIndex              // ML Kit
}

extension PoseJoint {
    static let mlKitOnly: Set<PoseJoint> = [
        .leftEyeInner, .leftEyeOuter, .rightEyeInner, .rightEyeOuter,
        .mouthLeft, .mouthRight,
        .leftPinky, .rightPinky, .leftIndex, .rightIndex, .leftThumb, .rightThumb,
        .leftHeel, .rightHeel, .leftFootIndex, .rightFootIndex
    ]

    static let visionOnly: Set<PoseJoint> = [.neck, .root]
}

/// Which side of the body to show. On side views the near and the far side overlap,
/// showing one of them makes the skeleton readable.
enum BodySide: String, CaseIterable, Identifiable, Codable {
    case both = "Both"
    case left = "Left"
    case right = "Right"

    var id: String { rawValue }
}

extension PoseJoint {
    /// The person's own side of the joint (`mouthLeft` is on the left too).
    /// `nil` for joints in the middle of the body: nose, neck, pelvis.
    var bodySide: BodySide? {
        let name = rawValue
        if name.hasPrefix("left") || name.hasSuffix("Left") { return .left }
        if name.hasPrefix("right") || name.hasSuffix("Right") { return .right }
        return nil
    }

    /// Joints in the middle of the body are visible with any side.
    func isVisible(for side: BodySide) -> Bool {
        side == .both || bodySide == nil || bodySide == side
    }
}

import Foundation

struct PoseLandmark: Codable, Hashable {
    let joint: PoseJoint
    let index: Int
    let position: CGPoint // normalized position (0...1) top-left
    let confidence: Float // 0...1
}

/// The 21 points of a hand, named like in Vision: the wrist and four joints for each finger.
/// ML Kit has only three of them (pinky, index, thumb) and no wrist-to-fingertip chain.
enum HandJoint: String, CaseIterable, Codable, Hashable {
    case wrist
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

struct HandLandmark: Codable, Hashable {
    let joint: HandJoint
    let position: CGPoint // normalized position (0...1) top-left
    let confidence: Float // 0...1
}

/// A hand found together with the body (Vision `detectsHands`).
struct DetectedHand: Codable, Hashable {
    let side: BodySide
    let landmarks: [HandLandmark]
}

struct DetectedPose: Codable, Hashable, Identifiable {
    var id = UUID()
    let landmarks: [PoseLandmark]
    /// Empty unless the engine was asked for hands. At most one per side.
    var hands: [DetectedHand] = []
    // fast access to landmark based on joint
    subscript(joint: PoseJoint) -> PoseLandmark? {
        landmarks.first { $0.joint == joint }
    }

    // only joints passed min confidence are allowed
    func landmarks(minConfidence: Float) -> [PoseLandmark] {
        landmarks.filter { $0.confidence >= minConfidence }
    }
}

enum PoseEngine: String, Codable, CaseIterable, Identifiable {
    case mlKit = "ML Kit"
    case vision = "Vision"

    var id: String { rawValue }
}

struct PoseDetectionResult: Codable {
    let engine: PoseEngine
    let imageSize: CGSize
    let poses: [DetectedPose]
    let duration: TimeInterval
}

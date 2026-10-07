import Foundation

struct Bone: Hashable {
    let from: PoseJoint
    let to: PoseJoint
}

enum Skeleton {
    static let bones: [Bone] = [
        // Face
        Bone(from: .leftEar, to: .leftEye),
        Bone(from: .leftEye, to: .nose),
        Bone(from: .nose, to: .rightEye),
        Bone(from: .rightEye, to: .rightEar),

        // Body
        Bone(from: .leftShoulder, to: .rightShoulder),
        Bone(from: .leftShoulder, to: .leftHip),
        Bone(from: .rightShoulder, to: .rightHip),
        Bone(from: .leftHip, to: .rightHip),

        // Vision: neck, hip
        Bone(from: .nose, to: .neck),
        Bone(from: .neck, to: .leftShoulder),
        Bone(from: .neck, to: .rightShoulder),
        Bone(from: .neck, to: .root),
        Bone(from: .root, to: .leftHip),
        Bone(from: .root, to: .rightHip),

        // Hands
        Bone(from: .leftShoulder, to: .leftElbow),
        Bone(from: .leftElbow, to: .leftWrist),
        Bone(from: .rightShoulder, to: .rightElbow),
        Bone(from: .rightElbow, to: .rightWrist),

        // ML Kit: wrist
        Bone(from: .leftWrist, to: .leftPinky),
        Bone(from: .leftWrist, to: .leftIndex),
        Bone(from: .leftWrist, to: .leftThumb),
        Bone(from: .leftPinky, to: .leftIndex),
        Bone(from: .rightWrist, to: .rightPinky),
        Bone(from: .rightWrist, to: .rightIndex),
        Bone(from: .rightWrist, to: .rightThumb),
        Bone(from: .rightPinky, to: .rightIndex),

        // Legs
        Bone(from: .leftHip, to: .leftKnee),
        Bone(from: .leftKnee, to: .leftAnkle),
        Bone(from: .rightHip, to: .rightKnee),
        Bone(from: .rightKnee, to: .rightAnkle),

        // ML Kit: feet
        Bone(from: .leftAnkle, to: .leftHeel),
        Bone(from: .leftHeel, to: .leftFootIndex),
        Bone(from: .leftAnkle, to: .leftFootIndex),
        Bone(from: .rightAnkle, to: .rightHeel),
        Bone(from: .rightHeel, to: .rightFootIndex),
        Bone(from: .rightAnkle, to: .rightFootIndex),
    ]
}

/// Lines of a hand: wrist to the base of every finger, each finger as a chain of joints,
/// and a line across the palm.
enum HandSkeleton {
    struct Bone: Hashable {
        let from: HandJoint
        let to: HandJoint
    }

    private static let fingers: [[HandJoint]] = [
        [.thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.littleMCP, .littlePIP, .littleDIP, .littleTip],
    ]

    static let bones: [Bone] = {
        var bones: [Bone] = []
        for finger in fingers {
            bones.append(Bone(from: .wrist, to: finger[0]))
            for pair in zip(finger, finger.dropFirst()) {
                bones.append(Bone(from: pair.0, to: pair.1))
            }
        }
        let bases: [HandJoint] = [.indexMCP, .middleMCP, .ringMCP, .littleMCP]
        for pair in zip(bases, bases.dropFirst()) {
            bones.append(Bone(from: pair.0, to: pair.1))
        }
        return bones
    }()
}

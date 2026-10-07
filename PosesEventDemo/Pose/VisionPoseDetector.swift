import UIKit
import Vision

/// Vision body pose with the Swift API (iOS 18+): one `await`, `Sendable` results, no callbacks.
/// `detectsHands` is always on: the same request also returns both hands, 21 points each.
nonisolated struct VisionPoseDetector: PoseDetector {
    let engine: PoseEngine = .vision

    /// Vision has no numeric landmark indices, so the index is the position in this list.
    private static let jointMapping: [(vision: HumanBodyPoseObservation.JointName, joint: PoseJoint)] = [
        (.nose, .nose),
        (.leftEye, .leftEye), (.rightEye, .rightEye),
        (.leftEar, .leftEar), (.rightEar, .rightEar),
        (.neck, .neck),
        (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
        (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
        (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
        (.root, .root),
        (.leftHip, .leftHip), (.rightHip, .rightHip),
        (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
        (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle),
    ]

    private static let handMapping: [(vision: HumanHandPoseObservation.JointName, joint: HandJoint)] = [
        (.wrist, .wrist),
        (.thumbCMC, .thumbCMC), (.thumbMP, .thumbMP), (.thumbIP, .thumbIP), (.thumbTip, .thumbTip),
        (.indexMCP, .indexMCP), (.indexPIP, .indexPIP), (.indexDIP, .indexDIP), (.indexTip, .indexTip),
        (.middleMCP, .middleMCP), (.middlePIP, .middlePIP), (.middleDIP, .middleDIP), (.middleTip, .middleTip),
        (.ringMCP, .ringMCP), (.ringPIP, .ringPIP), (.ringDIP, .ringDIP), (.ringTip, .ringTip),
        (.littleMCP, .littleMCP), (.littlePIP, .littlePIP), (.littleDIP, .littleDIP), (.littleTip, .littleTip),
    ]

    func detect(in image: UIImage) async throws -> PoseDetectionResult {
        guard let cgImage = image.cgImage else { throw PoseDetectorError.invalidImage }

        // `cgImage` has no orientation, it is stored separately in `UIImage`.
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let clock = ContinuousClock()
        let start = clock.now

        let poses = try await Self.performRequest(on: cgImage, orientation: orientation)

        return PoseDetectionResult(engine: engine,
                                   imageSize: image.size,
                                   poses: poses,
                                   duration: start.duration(to: clock.now).timeInterval)
    }

    /// `@concurrent`: always off the caller's actor, so the main thread is never blocked.
    @concurrent
    private static func performRequest(on cgImage: CGImage,
                                       orientation: CGImagePropertyOrientation) async throws -> [DetectedPose] {
        var request = DetectHumanBodyPoseRequest()
        request.detectsHands = true

        let observations = try await request.perform(on: cgImage, orientation: orientation)

        return observations.map { observation in
            let joints = observation.allJoints()

            let landmarks = jointMapping.enumerated().compactMap { index, entry -> PoseLandmark? in
                guard let joint = joints[entry.vision], isDetection(joint) else { return nil }

                // Vision: origin in the BOTTOM-left. The app uses top-left.
                return PoseLandmark(joint: entry.joint,
                                    index: index,
                                    position: joint.location.verticallyFlipped().cgPoint,
                                    confidence: joint.confidence)
            }

            var hands: [DetectedHand] = []
            if let left = observation.leftHand, let hand = makeHand(left, side: .left) { hands.append(hand) }
            if let right = observation.rightHand, let hand = makeHand(right, side: .right) { hands.append(hand) }

            return DetectedPose(landmarks: landmarks, hands: hands)
        }
    }

    private static func makeHand(_ observation: HumanHandPoseObservation, side: BodySide) -> DetectedHand? {
        let joints = observation.allJoints()
        let landmarks = handMapping.compactMap { entry -> HandLandmark? in
            guard let joint = joints[entry.vision], isDetection(joint) else { return nil }
            return HandLandmark(joint: entry.joint,
                                position: joint.location.verticallyFlipped().cgPoint,
                                confidence: joint.confidence)
        }
        return landmarks.isEmpty ? nil : DetectedHand(side: side, landmarks: landmarks)
    }

    /// For a joint it could not find, Vision still returns an entry: confidence 0 and
    /// a placeholder location in the corner of the image. That is not a detection:
    /// without this filter such points show up in the corner with the threshold at 0.
    private static func isDetection(_ joint: Joint) -> Bool {
        let x = joint.location.x
        let y = joint.location.y
        return joint.confidence > 0 && !(x == 0 && (y == 0 || y == 1))
    }
}

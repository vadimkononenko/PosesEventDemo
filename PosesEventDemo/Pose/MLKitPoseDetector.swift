import MLKitPoseDetection
import MLKitPoseDetectionAccurate
import MLKitPoseDetectionCommon
import MLKitVision
import UIKit

/// `PoseDetector` and `PoseLandmark` also exist in ML Kit. Inside this module our own types win,
/// ML Kit ones are referenced with the module name.
///
/// An `actor`: one detector is shared by the whole app (`PoseEngineFactory.shared`), so calls
/// from different screens or the warm-up could overlap, and ML Kit does not promise thread safety.
/// The actor runs them one at a time.
actor MLKitPoseDetector: PoseDetector {
    nonisolated let engine: PoseEngine = .mlKit

    /// The order matches the native ML Kit indices 0...32 (see the documentation).
    private static let jointMapping: [(type: PoseLandmarkType, joint: PoseJoint)] = [
        (.nose, .nose),
        (.leftEyeInner, .leftEyeInner), (.leftEye, .leftEye), (.leftEyeOuter, .leftEyeOuter),
        (.rightEyeInner, .rightEyeInner), (.rightEye, .rightEye), (.rightEyeOuter, .rightEyeOuter),
        (.leftEar, .leftEar), (.rightEar, .rightEar),
        (.mouthLeft, .mouthLeft), (.mouthRight, .mouthRight),
        (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
        (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
        (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
        (.leftPinkyFinger, .leftPinky), (.rightPinkyFinger, .rightPinky),
        (.leftIndexFinger, .leftIndex), (.rightIndexFinger, .rightIndex),
        (.leftThumb, .leftThumb), (.rightThumb, .rightThumb),
        (.leftHip, .leftHip), (.rightHip, .rightHip),
        (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
        (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle),
        (.leftHeel, .leftHeel), (.rightHeel, .rightHeel),
        (.leftToe, .leftFootIndex), (.rightToe, .rightFootIndex),
    ]

    private let detector: MLKitPoseDetectionCommon.PoseDetector

    init() {
        let options = AccuratePoseDetectorOptions()
        options.detectorMode = .singleImage
        detector = MLKitPoseDetectionCommon.PoseDetector.poseDetector(options: options)
    }

    func detect(in image: UIImage) async throws -> PoseDetectionResult {
        let clock = ContinuousClock()
        let start = clock.now

        let input = try await Self.uprightPixels(of: image)
        let poses = try runDetector(on: input)

        return PoseDetectionResult(engine: engine,
                                   imageSize: image.size,
                                   poses: poses,
                                   duration: start.duration(to: clock.now).timeInterval)
    }

    /// ML Kit always gets upright pixels with `.up`: then its coordinates are exactly
    /// in the space of the bitmap we pass, with no rotation left to guess.
    /// `@concurrent`: the redraw runs off any actor and does not hold this one.
    @concurrent
    private nonisolated static func uprightPixels(of image: UIImage) async throws -> CGImage {
        guard let input = UprightImageRenderer.render(image) else { throw PoseDetectorError.invalidImage }
        return input
    }

    /// Synchronous and heavy. Runs on the actor, so only one call uses the detector at a time.
    private func runDetector(on input: CGImage) throws -> [DetectedPose] {
        let visionImage = VisionImage(image: UIImage(cgImage: input))
        visionImage.orientation = .up

        let pixelSize = CGSize(width: input.width, height: input.height)
        return try detector.results(in: visionImage).map { Self.makePose($0, pixelSize: pixelSize) }
    }

    private static func makePose(_ pose: Pose, pixelSize: CGSize) -> DetectedPose {
        let landmarks = jointMapping.enumerated().map { index, entry in
            let landmark = pose.landmark(ofType: entry.type)
            return PoseLandmark(joint: entry.joint,
                                index: index,
                                position: CGPoint(x: landmark.position.x / pixelSize.width,
                                                  y: landmark.position.y / pixelSize.height),
                                confidence: landmark.inFrameLikelihood)
        }
        return DetectedPose(landmarks: landmarks)
    }
}

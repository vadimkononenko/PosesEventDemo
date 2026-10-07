import MLKitPoseDetection
import MLKitPoseDetectionAccurate
import MLKitPoseDetectionCommon
import MLKitVision
import UIKit

/// `PoseDetector` and `PoseLandmark` also exist in ML Kit. Inside this module our own types win,
/// ML Kit ones are referenced with the module name.
nonisolated final class MLKitPoseDetector: PoseDetector, @unchecked Sendable {
    let engine: PoseEngine = .mlKit

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
    /// One detector is shared by the whole app (`PoseEngineFactory.shared`), so calls from
    /// different screens or the warm-up could overlap. ML Kit does not promise thread safety.
    private let lock = NSLock()

    init() {
        let options = AccuratePoseDetectorOptions()
        options.detectorMode = .singleImage
        detector = MLKitPoseDetectionCommon.PoseDetector.poseDetector(options: options)
    }

    func detect(in image: UIImage) async throws -> PoseDetectionResult {

        let clock = ContinuousClock()
        let start = clock.now

        let poses = try await Task.detached(priority: .userInitiated) {
            // ML Kit always gets upright pixels with `.up`: then its coordinates are exactly
            // in the space of the bitmap we pass, with no rotation left to guess.
            guard let input = UprightImageRenderer.render(image) else {
                throw PoseDetectorError.invalidImage
            }

            let visionImage = VisionImage(image: UIImage(cgImage: input))
            visionImage.orientation = .up

            let pixelSize = CGSize(width: input.width, height: input.height)
            let results = try self.lock.withLock { try self.detector.results(in: visionImage) }
            return results.map { Self.makePose($0, pixelSize: pixelSize) }
        }.value

        return PoseDetectionResult(engine: engine,
                                   imageSize: image.size,
                                   poses: poses,
                                   duration: start.duration(to: clock.now).timeInterval)
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

import UIKit
import Vision
import simd

/// `DetectHumanBodyPose3DRequest`: 17 joints in meters and an estimate of the body height.
/// ML Kit has no counterpart: it gives only a rough Z value for each landmark.
nonisolated struct VisionPose3DDetector {
    func detect(in image: UIImage) async throws -> Pose3DResult {
        guard let cgImage = image.cgImage else { throw PoseDetectorError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        let clock = ContinuousClock()
        let start = clock.now

        let people = try await Self.performRequest(on: cgImage, orientation: orientation)

        return Pose3DResult(people: people, duration: start.duration(to: clock.now).timeInterval)
    }

    /// `@concurrent`: always off the caller's actor, so the main thread is never blocked.
    @concurrent
    private static func performRequest(on cgImage: CGImage,
                                       orientation: CGImagePropertyOrientation) async throws -> [Pose3DPerson] {
        let request = DetectHumanBodyPose3DRequest()
        let observations = try await request.perform(on: cgImage, orientation: orientation)

        return observations.map { observation in
            let joints = observation.allJoints().map { name, joint -> Pose3DJoint in
                let parent = observation.parentJointName(for: name)
                // `position` is a 4x4 transform relative to the root, the translation is in the last column.
                let translation = joint.position.columns.3
                return Pose3DJoint(name: name.rawValue,
                                   // The root is its own parent: there is no bone to draw for it.
                                   parent: parent == name ? nil : parent.rawValue,
                                   position: SIMD3(translation.x, translation.y, translation.z))
            }

            return Pose3DPerson(joints: joints,
                                bodyHeightMeters: observation.bodyHeight.converted(to: .meters).value,
                                isHeightMeasured: observation.heightEstimationTechnique == .measured)
        }
    }
}

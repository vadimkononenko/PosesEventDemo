import UIKit

enum PoseDetectorError: Error {
    case invalidImage
}

/// `Sendable`: detectors are used from the background actors of the video pipeline.
nonisolated protocol PoseDetector: Sendable {
    var engine: PoseEngine { get }

    func detect(in image: UIImage) async throws -> PoseDetectionResult
}

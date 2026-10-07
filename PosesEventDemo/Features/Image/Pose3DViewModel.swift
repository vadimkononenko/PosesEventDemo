import Observation
import UIKit

/// Runs the 3D pose request on a photo for the 3D sheet.
@MainActor
@Observable
final class Pose3DViewModel {
    enum State {
        case idle
        case loading
        case done(Pose3DResult)
        case failed(String)
    }

    private(set) var state: State = .idle

    private let detector = VisionPose3DDetector()

    func detect(in image: UIImage) async {
        state = .loading
        do {
            state = .done(try await detector.detect(in: image))
        } catch {
            // For example, the request is not supported on the simulator.
            state = .failed(error.localizedDescription)
        }
    }
}

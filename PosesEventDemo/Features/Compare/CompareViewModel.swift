import SwiftUI

@MainActor
@Observable
final class CompareViewModel {
    var overlayMode: OverlayMode = .skeleton
    var minConfidence: Float = 0
    var side: BodySide = .both

    private(set) var image: UIImage?
    private(set) var results: [PoseEngine: PoseDetectionResult] = [:]
    private(set) var errors: [PoseEngine: String] = [:]
    private(set) var isDetecting: Bool = false
    /// How many times the engines were run on this image (1 for the first run).
    private(set) var runCount = 0

    private var detectionTask: Task<Void, Never>?
    /// Incremented on every new run, so a superseded run can notice it and stop.
    private var generation = 0

    private func detector(for engine: PoseEngine) -> any PoseDetector {
        PoseEngineFactory.detector(for: engine)
    }

    /// Runs both engines on this image.
    func setImage(_ newImage: UIImage) {
        image = newImage
        runDetection()
    }

    /// Runs both engines again on the same image. Results can differ between runs,
    /// which is worth showing for the borderline cases.
    func rerun() {
        guard image != nil, !isDetecting else { return }
        runDetection()
    }

    /// Engines run one after another, not at the same time: the durations in the
    /// comparison table are then not distorted by the engines competing for the CPU.
    /// Each result appears as soon as it is ready.
    private func runDetection() {
        detectionTask?.cancel()
        generation += 1
        runCount += 1
        results = [:]
        errors = [:]

        guard let image else {
            isDetecting = false
            return
        }

        let generation = generation
        isDetecting = true

        detectionTask = Task {
            for engine in PoseEngine.allCases {
                guard generation == self.generation else { return }

                do {
                    let detected = try await detector(for: engine)
                        .detect(in: image)
                    guard generation == self.generation else { return }
                    results[engine] = detected
                } catch {
                    guard generation == self.generation else { return }
                    errors[engine] = error.localizedDescription
                }
            }
            if generation == self.generation { isDetecting = false }
        }
    }
}

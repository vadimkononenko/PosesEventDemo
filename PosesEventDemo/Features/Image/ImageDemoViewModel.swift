import SwiftUI
import Photos

@MainActor
@Observable
final class ImageDemoViewModel {
    // MARK: Controls

    var engine: PoseEngine = .vision {
        didSet { detectIfNeeded() }
    }

    var overlayMode: OverlayMode = .skeleton
    var minConfidence: Float = 0
    var side: BodySide = .both

    // MARK: State

    private(set) var image: UIImage?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    /// Results for the current photo and orientation setting, one per engine.
    /// Switching the engine back and forth does not run the detection again.
    private(set) var results: [PoseEngine: PoseDetectionResult] = [:]

    var result: PoseDetectionResult? { results[engine] }
    var isDetecting: Bool { detecting.contains(engine) }

    private var detecting: Set<PoseEngine> = []
    /// Incremented when the cached results become obsolete, so late answers can be ignored.
    private var generation = 0

    private func detector(for engine: PoseEngine) -> any PoseDetector {
        PoseEngineFactory.detector(for: engine)
    }

    func select(_ asset: PHAsset) {
        Task { await loadImage(from: asset) }
    }

    private func loadImage(from asset: PHAsset) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            image = try await MediaAssetLoader.loadImage(asset)
            invalidateResults()
            detectIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func invalidateResults() {
        generation += 1
        results = [:]
        detecting = []
        errorMessage = nil
    }

    private func detectIfNeeded() {
        guard let image, results[engine] == nil, !detecting.contains(engine) else { return }

        let engine = engine
        let generation = generation
        let detector = detector(for: engine)
        detecting.insert(engine)

        Task {
            defer {
                if generation == self.generation { detecting.remove(engine) }
            }

            do {
                let detected = try await detector.detect(in: image)
                guard generation == self.generation else { return }
                results[engine] = detected
            } catch {
                guard generation == self.generation else { return }
                errorMessage = error.localizedDescription
            }
        }
    }
}

import UIKit

/// The only place that knows about the concrete detectors.
/// UI code asks for a `PoseDetector` by `PoseEngine` and never imports ML Kit or Vision.
nonisolated enum PoseEngineFactory {
    static func makeDetector(for engine: PoseEngine) -> any PoseDetector {
        switch engine {
        case .mlKit: MLKitPoseDetector()
        case .vision: VisionPoseDetector()
        }
    }

    /// One detector per engine for the whole app. Creating an ML Kit detector loads its model,
    /// which used to freeze every screen that created its own detector.
    /// `static let` is initialized lazily and thread-safely on first access.
    static let shared: [PoseEngine: any PoseDetector] = Dictionary(
        uniqueKeysWithValues: PoseEngine.allCases.map { ($0, makeDetector(for: $0)) }
    )

    static func detector(for engine: PoseEngine) -> any PoseDetector {
        shared[engine] ?? makeDetector(for: engine)
    }

    /// Loads the models in the background right after the launch, so the first real
    /// detection on a screen does not pay for it. The result on a blank image is ignored.
    static func warmUp() async {
        await Task.detached(priority: .utility) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let blank = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            }

            for engine in PoseEngine.allCases {
                _ = try? await detector(for: engine).detect(in: blank)
            }
        }.value
    }
}

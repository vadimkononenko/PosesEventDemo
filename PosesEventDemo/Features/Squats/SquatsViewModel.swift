import Foundation
import Observation
import Photos

/// Squat counting on top of the video analysis.
///
/// Choosing a video, the analysis by both engines and the playback are done by
/// `VideoAnalysisViewModel`, exactly as on the Video screen. This view model adds
/// what is specific to squats: which person is counted, the repetitions and the checks.
@MainActor
@Observable
final class SquatsViewModel {
    let video: VideoAnalysisViewModel

    /// Count a down-and-up only if it looks like a squat (upright torso, sensible duration).
    var checksEnabled = true

    @ObservationIgnored private var cache: (resultID: UUID, checksEnabled: Bool, analysis: SquatAnalysis)?

    init(video: VideoAnalysisViewModel? = nil) {
        self.video = video ?? VideoAnalysisViewModel()
    }

    // MARK: Forwarded from the video analysis

    var state: VideoAnalysisViewState { video.state }

    var configuration: AnalysisConfiguration {
        get { video.configuration }
        set { video.configuration = newValue }
    }

    func select(_ asset: PHAsset) { video.select(asset) }
    func startAnalysis() { video.startAnalysis() }
    func cancelAnalysis() { video.cancelAnalysis() }
    func prepareForReanalysis() { video.prepareForReanalysis() }
    func togglePlayback() { video.togglePlayback() }
    func seek(to seconds: Double) { video.seek(to: seconds) }
    func pause() { video.pause() }

    // MARK: Squats

    /// The count for the finished analysis. Computed once per analysis and per toggle
    /// value, not on every playback tick.
    var squats: SquatAnalysis? {
        guard case .completed(let completed) = video.state else { return nil }

        if let cache, cache.resultID == completed.result.id, cache.checksEnabled == checksEnabled {
            return cache.analysis
        }
        let analysis = SquatAnalysis(frames: completed.result.frames, checksEnabled: checksEnabled)
        cache = (completed.result.id, checksEnabled, analysis)
        return analysis
    }

    /// Repetitions so far, the state and the knee angle of one engine at the current moment.
    func currentSample(for engine: PoseEngine) -> SquatTimeline.Sample? {
        guard case .completed(let completed) = video.state else { return nil }
        return squats?.timelines[engine]?.sample(at: completed.playback.time)
    }

    func timeline(for engine: PoseEngine) -> SquatTimeline? {
        squats?.timelines[engine]
    }

    /// The frame on the screen with only the counted person left, so it is clear whose
    /// squats are counted. During the analysis (no count yet) the person is picked per frame.
    var displayedFrame: FrameAnalysis? {
        guard let frame = video.state.displayedAnalysis else { return nil }
        let indices = squats?.subject[frame.index]
            ?? SquatSubject.select(in: frame, previousCenter: nil).indices

        var poses: [PoseEngine: PoseDetectionResult] = [:]
        for (engine, result) in frame.poses {
            let kept = indices[engine].flatMap { $0 < result.poses.count ? [result.poses[$0]] : nil } ?? []
            poses[engine] = PoseDetectionResult(engine: result.engine,
                                                imageSize: result.imageSize,
                                                poses: kept,
                                                duration: result.duration)
        }
        return FrameAnalysis(index: frame.index, time: frame.time, people: frame.people, poses: poses)
    }

    // MARK: Text for the screen

    /// "torso tilted 7 · too fast 2"
    func rejectionSummary(for engine: PoseEngine) -> String {
        guard let rejected = timeline(for: engine)?.rejected else { return "" }
        return RejectReason.allCases
            .compactMap { reason in rejected[reason].map { "\(reason.rawValue) \($0)" } }
            .joined(separator: " · ")
    }

    /// Whether the engine saw the legs at all; without them there is nothing to count.
    func foundLegs(for engine: PoseEngine) -> Bool {
        timeline(for: engine)?.samples.contains { $0.kneeAngle != nil } ?? true
    }
}

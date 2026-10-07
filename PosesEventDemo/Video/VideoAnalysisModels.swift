import Foundation

nonisolated struct AnalysisConfiguration: Equatable {
    /// How many frames of each second of video go through detection.
    var framesPerSecond: Double = 10
    /// Frames are scaled down to this size (the longest side). `nil`: the original size.
    var maximumPixelDimension: Int? = 1280
}

/// Everything found on one sampled frame, for both engines.
nonisolated struct FrameAnalysis {
    let index: Int
    /// Time in the video, seconds.
    let time: TimeInterval
    /// Bounding boxes of people (Vision).
    let people: [PersonBox]
    let poses: [PoseEngine: PoseDetectionResult]
}

nonisolated struct VideoAnalysisProgress {
    let fractionCompleted: Double
    let analyzedFrameCount: Int
    let latest: FrameAnalysis
}

nonisolated struct VideoAnalysisResult {
    /// Identifies this analysis, so results derived from it can be cached.
    let id = UUID()
    let configuration: AnalysisConfiguration
    /// Sorted by time.
    let frames: [FrameAnalysis]

    /// The analyzed frame closest to `time`.
    func analysis(nearestTo time: TimeInterval) -> FrameAnalysis? {
        guard !frames.isEmpty else { return nil }

        // First frame with `frame.time >= time`.
        var low = 0
        var high = frames.count - 1
        while low < high {
            let middle = (low + high) / 2
            if frames[middle].time < time {
                low = middle + 1
            } else {
                high = middle
            }
        }

        if low > 0, abs(frames[low - 1].time - time) <= abs(frames[low].time - time) {
            return frames[low - 1]
        }
        return frames[low]
    }

    func framesWithPose(for engine: PoseEngine) -> Int {
        frames.filter { !($0.poses[engine]?.poses.isEmpty ?? true) }.count
    }

    /// Total time the engine spent on all frames, seconds.
    func totalTime(for engine: PoseEngine) -> TimeInterval {
        frames.reduce(0) { $0 + ($1.poses[engine]?.duration ?? 0) }
    }

    func averageTime(for engine: PoseEngine) -> TimeInterval {
        frames.isEmpty ? 0 : totalTime(for: engine) / Double(frames.count)
    }
}

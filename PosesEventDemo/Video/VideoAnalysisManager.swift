import UIKit

/// Runs the whole pipeline: frames -> people boxes (Vision) and a pose from EACH engine.
///
/// Frames go one after another, the engines also go one after another on every frame:
/// then the milliseconds shown to the audience are not distorted by two engines
/// competing for the CPU.
actor VideoAnalysisManager {
    enum Event: Sendable {
        /// After every analyzed frame.
        case progress(VideoAnalysisProgress)
        /// The last event: the whole result.
        case finished(VideoAnalysisResult)
    }

    enum AnalysisError: LocalizedError {
        case alreadyInProgress

        var errorDescription: String? { "Another analysis is already running" }
    }

    private let extractor = FrameExtractor()
    private let personDetector = VisionPersonDetector()
    private let poseDetectors = PoseEngineFactory.shared

    private var frames: [FrameAnalysis] = []
    private var isAnalyzing = false

    /// The analysis as a stream: `.progress` for every frame, then `.finished`.
    /// When the consumer stops iterating (its task is cancelled), the analysis is cancelled too.
    nonisolated func analyze(video: ImportedVideo,
                             configuration: AnalysisConfiguration) -> AsyncThrowingStream<Event, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Event.self)

        let task = Task {
            do {
                let result = try await run(video: video, configuration: configuration, events: continuation)
                continuation.yield(.finished(result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in
            task.cancel()
            Task { await self.cancel() }
        }
        return stream
    }

    private func run(video: ImportedVideo,
                     configuration: AnalysisConfiguration,
                     events: AsyncThrowingStream<Event, Error>.Continuation) async throws -> VideoAnalysisResult {
        guard !isAnalyzing else { throw AnalysisError.alreadyInProgress }
        isAnalyzing = true
        frames.removeAll(keepingCapacity: true)
        defer {
            isAnalyzing = false
            frames.removeAll(keepingCapacity: true)
        }

        _ = try await extractor.extractFrames(
            from: video,
            framesPerSecond: configuration.framesPerSecond,
            maximumPixelDimension: configuration.maximumPixelDimension
        ) { [weak self] frame in
            guard let self else { throw CancellationError() }

            let analysis = try await self.analyze(frame)
            let count = await self.store(analysis)
            events.yield(.progress(VideoAnalysisProgress(fractionCompleted: frame.progress,
                                                         analyzedFrameCount: count,
                                                         latest: analysis)))
        }

        try Task.checkCancellation()
        return VideoAnalysisResult(configuration: configuration, frames: frames)
    }

    func cancel() async {
        await extractor.cancel()
    }

    private func analyze(_ frame: ExtractedFrame) async throws -> FrameAnalysis {
        let people = try personDetector.detect(in: frame.image)

        // The frame is upright, so both engines get it as is.
        let image = UIImage(cgImage: frame.image)
        var poses: [PoseEngine: PoseDetectionResult] = [:]
        for engine in PoseEngine.allCases {
            try Task.checkCancellation()
            if let detector = poseDetectors[engine] {
                poses[engine] = try await detector.detect(in: image)
            }
        }

        return FrameAnalysis(index: frame.index, time: frame.time, people: people, poses: poses)
    }

    private func store(_ analysis: FrameAnalysis) -> Int {
        frames.append(analysis)
        return frames.count
    }
}

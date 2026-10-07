import AVFoundation
import Observation
import Photos

@MainActor
@Observable
final class VideoAnalysisViewModel {
    private let analysisManager = VideoAnalysisManager()

    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var playbackController: VideoPlaybackController?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?

    private(set) var state: VideoAnalysisViewState = .empty

    /// Settings for the next analysis.
    var configuration = AnalysisConfiguration()
    var overlaySettings = VideoOverlaySettings()

    isolated deinit {
        analysisTask?.cancel()
        playbackTask?.cancel()
    }

    // MARK: Choosing a video

    func select(_ asset: PHAsset) {
        Task { await selectVideo(asset) }
    }

    private func selectVideo(_ asset: PHAsset) async {
        await stopCurrentWork()
        state = .importing

        do {
            let urlAsset = try await MediaAssetLoader.loadVideo(asset)
            let video = try await ImportedVideo.load(from: urlAsset)

            // A video cannot be sampled more often than it has frames.
            let sourceRate = Double(video.nominalFrameRate)
            if sourceRate > 0, configuration.framesPerSecond > sourceRate {
                configuration.framesPerSecond = max(sourceRate.rounded(.down), 1)
            }

            state = .ready(configurePlayback(for: video))
        } catch {
            state = .failed(FailedAnalysis(session: nil, message: error.localizedDescription))
        }
    }

    // MARK: Analysis

    func startAnalysis() {
        guard let session = state.session, state.canStartAnalysis else { return }

        analysisTask?.cancel()
        playbackController?.pause()
        state = .analyzing(AnalysisInProgress(session: session, progress: nil))

        let selectedConfiguration = configuration
        let video = session.video

        analysisTask = Task { [weak self] in
            guard let self else { return }

            do {
                for try await event in analysisManager.analyze(video: video, configuration: selectedConfiguration) {
                    switch event {
                    case .progress(let progress): receive(progress)
                    case .finished(let result): complete(with: result)
                    }
                }
                // A cancelled consumer just leaves the loop, without an error.
                if Task.isCancelled { transitionToCancelled() }
            } catch is CancellationError {
                transitionToCancelled()
            } catch {
                transitionToFailed(with: error)
            }
        }
    }

    func cancelAnalysis() {
        guard state.isAnalyzing else { return }

        analysisTask?.cancel()
        Task { await analysisManager.cancel() }
    }

    func prepareForReanalysis() {
        guard let session = state.session, !state.isAnalyzing else { return }

        playbackController?.pause()
        playbackController?.displayFrame(at: 0)
        state = .ready(session)
    }

    // MARK: Playback

    func togglePlayback() {
        guard case .completed(let analysis) = state else { return }
        playbackController?.toggle(from: analysis.playback)
    }

    func seek(to seconds: Double) {
        guard case .completed(let analysis) = state else { return }
        playbackController?.seek(to: seconds, preserving: analysis.playback)
    }

    func pause() {
        playbackController?.pause()
    }
}

// MARK: - State transitions

private extension VideoAnalysisViewModel {
    func receive(_ progress: VideoAnalysisProgress) {
        guard case .analyzing(let analysis) = state else { return }

        // Live view: the player shows the frame that has just been analyzed.
        playbackController?.displayFrame(at: progress.latest.time)
        state = .analyzing(AnalysisInProgress(session: analysis.session, progress: progress))
    }

    func receive(_ playback: VideoPlaybackState) {
        guard case .completed(let analysis) = state else { return }

        state = .completed(CompletedAnalysis(session: analysis.session,
                                             result: analysis.result,
                                             currentAnalysis: analysis.result.analysis(nearestTo: playback.time),
                                             playback: playback))
    }

    func complete(with result: VideoAnalysisResult) {
        guard case .analyzing(let analysis) = state else { return }

        let first = result.frames.first
        let initialTime = first?.time ?? 0

        playbackController?.pause()
        playbackController?.displayFrame(at: initialTime)
        state = .completed(CompletedAnalysis(session: analysis.session,
                                             result: result,
                                             currentAnalysis: first,
                                             playback: .paused(time: initialTime)))
    }

    func transitionToCancelled() {
        guard case .analyzing(let analysis) = state else { return }
        state = .cancelled(analysis.session)
    }

    func transitionToFailed(with error: Error) {
        guard case .analyzing(let analysis) = state else { return }
        state = .failed(FailedAnalysis(session: analysis.session, message: error.localizedDescription))
    }
}

// MARK: - Video lifecycle

private extension VideoAnalysisViewModel {
    func configurePlayback(for video: ImportedVideo) -> VideoSession {
        let controller = VideoPlaybackController(video: video)
        playbackTask?.cancel()
        playbackTask = Task { [weak self, states = controller.states] in
            for await playback in states {
                self?.receive(playback)
            }
        }
        playbackController = controller

        return VideoSession(video: video, player: controller.player)
    }

    func stopCurrentWork() async {
        let currentTask = analysisTask
        currentTask?.cancel()
        analysisTask = nil
        playbackController?.pause()

        await analysisManager.cancel()
        await currentTask?.value

        playbackTask?.cancel()
        playbackTask = nil
        playbackController = nil
    }
}

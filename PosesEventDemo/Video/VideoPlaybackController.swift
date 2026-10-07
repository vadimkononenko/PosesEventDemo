import AVFoundation

enum VideoPlaybackState {
    case paused(time: Double)
    case playing(time: Double)

    var time: Double {
        switch self {
        case .paused(let time), .playing(let time): time
        }
    }

    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    func updatingTime(_ time: Double) -> VideoPlaybackState {
        switch self {
        case .paused: .paused(time: time)
        case .playing: .playing(time: time)
        }
    }
}

/// Owns the `AVPlayer` and reports its state as an `AsyncStream`.
/// The same player is shown by both engine panels.
@MainActor
final class VideoPlaybackController {
    let player: AVPlayer

    /// Every change: the periodic time, play / pause, seeks. Ends when the controller is released.
    let states: AsyncStream<VideoPlaybackState>
    private let stateContinuation: AsyncStream<VideoPlaybackState>.Continuation

    private let duration: Double
    private var timeObserver: Any?
    private var timeTask: Task<Void, Never>?

    init(video: ImportedVideo) {
        duration = video.duration
        player = AVPlayer(playerItem: AVPlayerItem(asset: video.asset))
        player.actionAtItemEnd = .pause

        // Only the latest state matters: an old time is useless once a newer one exists.
        (states, stateContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))

        // AVPlayer has no async API for the time, so its observer is turned into a stream once,
        // here, and read with `for await` on the main actor.
        let (times, timeContinuation) = AsyncStream.makeStream(of: CMTime.self,
                                                               bufferingPolicy: .bufferingNewest(1))
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                                                      queue: .main) { time in
            timeContinuation.yield(time)
        }
        timeTask = Task { [weak self] in
            for await time in times {
                self?.publishState(at: time)
            }
        }
    }

    isolated deinit {
        timeTask?.cancel()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        stateContinuation.finish()
    }

    func pause() {
        player.pause()
    }

    /// Shows the frame at this time without playing. Used for the live view during the analysis.
    func displayFrame(at seconds: Double) {
        seekPlayer(to: bounded(seconds))
    }

    func toggle(from playback: VideoPlaybackState) {
        if playback.isPlaying {
            player.pause()
            stateContinuation.yield(.paused(time: playback.time))
            return
        }

        var startTime = playback.time
        if startTime >= duration - 0.1 {
            startTime = 0
            seekPlayer(to: startTime)
        }

        player.play()
        stateContinuation.yield(.playing(time: startTime))
    }

    func seek(to seconds: Double, preserving playback: VideoPlaybackState) {
        let time = bounded(seconds)
        seekPlayer(to: time)
        stateContinuation.yield(playback.updatingTime(time))
    }

    private func publishState(at time: CMTime) {
        let seconds = time.seconds
        guard seconds.isFinite else { return }

        let bounded = bounded(seconds)
        stateContinuation.yield(player.timeControlStatus == .playing ? .playing(time: bounded) : .paused(time: bounded))
    }

    private func seekPlayer(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero)
    }

    private func bounded(_ seconds: Double) -> Double {
        min(max(seconds, 0), duration)
    }
}

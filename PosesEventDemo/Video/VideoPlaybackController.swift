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

/// Owns the `AVPlayer` and reports its time. The same player is shown by both engine panels.
@MainActor
final class VideoPlaybackController {
    let player: AVPlayer

    var onStateChange: ((VideoPlaybackState) -> Void)?

    private let duration: Double
    private var timeObserver: Any?

    init(video: ImportedVideo) {
        duration = video.duration
        player = AVPlayer(playerItem: AVPlayerItem(asset: video.asset))
        player.actionAtItemEnd = .pause

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                                                      queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.publishState(at: time)
            }
        }
    }

    isolated deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
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
            onStateChange?(.paused(time: playback.time))
            return
        }

        var startTime = playback.time
        if startTime >= duration - 0.1 {
            startTime = 0
            seekPlayer(to: startTime)
        }

        player.play()
        onStateChange?(.playing(time: startTime))
    }

    func seek(to seconds: Double, preserving playback: VideoPlaybackState) {
        let time = bounded(seconds)
        seekPlayer(to: time)
        onStateChange?(playback.updatingTime(time))
    }

    private func publishState(at time: CMTime) {
        let seconds = time.seconds
        guard seconds.isFinite else { return }

        let bounded = bounded(seconds)
        onStateChange?(player.timeControlStatus == .playing ? .playing(time: bounded) : .paused(time: bounded))
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

import AVFoundation

struct VideoSession {
    let video: ImportedVideo
    let player: AVPlayer
}

struct AnalysisInProgress {
    let session: VideoSession
    let progress: VideoAnalysisProgress?
}

struct CompletedAnalysis {
    let session: VideoSession
    let result: VideoAnalysisResult
    /// The analyzed frame closest to the playback time.
    let currentAnalysis: FrameAnalysis?
    let playback: VideoPlaybackState
}

struct FailedAnalysis {
    let session: VideoSession?
    let message: String
}

/// Which step the screen is on: choose a video -> settings -> live analysis -> results.
enum VideoAnalysisViewState {
    case empty
    case importing
    case ready(VideoSession)
    case analyzing(AnalysisInProgress)
    case completed(CompletedAnalysis)
    case failed(FailedAnalysis)
    case cancelled(VideoSession)

    var session: VideoSession? {
        switch self {
        case .ready(let session), .cancelled(let session): session
        case .analyzing(let analysis): analysis.session
        case .completed(let analysis): analysis.session
        case .failed(let failure): failure.session
        case .empty, .importing: nil
        }
    }

    /// The frame whose result is drawn over the video now.
    var displayedAnalysis: FrameAnalysis? {
        switch self {
        case .analyzing(let analysis): analysis.progress?.latest
        case .completed(let analysis): analysis.currentAnalysis
        default: nil
        }
    }

    var isImporting: Bool {
        if case .importing = self { return true }
        return false
    }

    var isAnalyzing: Bool {
        if case .analyzing = self { return true }
        return false
    }

    var canStartAnalysis: Bool {
        switch self {
        case .ready, .completed, .cancelled: true
        case .failed(let failure): failure.session != nil
        case .empty, .importing, .analyzing: false
        }
    }
}

/// What is drawn over the video. Changing it never needs a new analysis.
struct VideoOverlaySettings: Equatable {
    var showsBoxes = true
    var showsSkeleton = true
    var showsLandmarks = true
    var minConfidence: Float = 0
    var side: BodySide = .both
}

import AVFoundation
import CoreImage

/// A sampled frame, already rotated to how the user sees the video.
nonisolated struct ExtractedFrame: @unchecked Sendable {
    let index: Int
    /// Presentation time in the video, seconds.
    let time: TimeInterval
    let image: CGImage
    /// 0...1
    let progress: Double
}

nonisolated enum FrameExtractionError: LocalizedError {
    case alreadyInProgress
    case videoTrackNotFound
    case unsupportedTransform
    case cannotStartReading(String?)
    case readingFailed(String?)
    case noFramesExtracted

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress: "Another analysis is already running"
        case .videoTrackNotFound: "The file has no video track"
        case .unsupportedTransform: "This video rotation is not supported"
        case .cannotStartReading(let reason): "Cannot read the video" + (reason.map { ": \($0)" } ?? "")
        case .readingFailed(let reason): "Reading the video failed" + (reason.map { ": \($0)" } ?? "")
        case .noFramesExtracted: "No frames could be read from the video"
        }
    }
}

/// Decodes the video sequentially with `AVAssetReader` and hands out every N-th frame.
///
/// The next frame is decoded only after `onFrame` has finished with the current one (backpressure),
/// so memory does not grow with the length of the video, in contrast to `AVAssetImageGenerator` batches.
actor FrameExtractor {
    private let ciContext = CIContext()
    private var activeReader: AVAssetReader?
    private var isExtracting = false

    /// - Returns: the number of delivered frames.
    func extractFrames(from video: ImportedVideo,
                       framesPerSecond: Double,
                       maximumPixelDimension: Int?,
                       onFrame: @Sendable (ExtractedFrame) async throws -> Void) async throws -> Int {
        guard !isExtracting else { throw FrameExtractionError.alreadyInProgress }
        isExtracting = true
        defer { isExtracting = false }

        guard let track = try await video.asset.loadTracks(withMediaType: .video).first else {
            throw FrameExtractionError.videoTrackNotFound
        }
        guard let orientation = VideoOrientationResolver().orientation(for: video.preferredTransform) else {
            throw FrameExtractionError.unsupportedTransform
        }
        let timelineStart = try await track.load(.timeRange).start.seconds

        let reader = try AVAssetReader(asset: video.asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings(
            sourceSize: video.naturalSize,
            maximumPixelDimension: maximumPixelDimension
        ))
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else { throw FrameExtractionError.cannotStartReading(nil) }
        reader.add(output)
        guard reader.startReading() else {
            throw FrameExtractionError.cannotStartReading(reader.error?.localizedDescription)
        }

        activeReader = reader
        defer {
            if reader.status == .reading { reader.cancelReading() }
            activeReader = nil
        }

        let interval = 1 / max(framesPerSecond, 0.1)
        let tolerance = 0.001
        var nextTime = timelineStart
        var lastTime = -Double.infinity
        var delivered = 0

        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()

            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            guard time.isValid, time.isNumeric else { continue }
            let seconds = time.seconds

            guard seconds + tolerance >= nextTime, seconds > lastTime,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sample),
                  let image = UprightImageRenderer.render(CIImage(cvPixelBuffer: pixelBuffer),
                                                          orientation: orientation,
                                                          context: ciContext) else { continue }

            let progress = min(max((seconds - timelineStart) / video.duration, 0), 1)
            try await onFrame(ExtractedFrame(index: delivered, time: seconds, image: image, progress: progress))

            delivered += 1
            lastTime = seconds
            // Move the target forward from the schedule, not from the actual time: no drift.
            repeat { nextTime += interval } while nextTime <= seconds + tolerance

            await Task.yield()
        }

        switch reader.status {
        case .cancelled: throw CancellationError()
        case .failed: throw FrameExtractionError.readingFailed(reader.error?.localizedDescription)
        default: break
        }
        guard delivered > 0 else { throw FrameExtractionError.noFramesExtracted }
        return delivered
    }

    func cancel() {
        activeReader?.cancelReading()
    }

    private func outputSettings(sourceSize: CGSize, maximumPixelDimension: Int?) -> [String: Any] {
        var settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]

        // The decoder scales the frames, which is cheaper than decoding in full size.
        let width = abs(sourceSize.width)
        let height = abs(sourceSize.height)
        if let maximumPixelDimension, max(width, height) > CGFloat(maximumPixelDimension) {
            let scale = CGFloat(maximumPixelDimension) / max(width, height)
            settings[kCVPixelBufferWidthKey as String] = max(Int((width * scale).rounded(.down)), 1)
            settings[kCVPixelBufferHeightKey as String] = max(Int((height * scale).rounded(.down)), 1)
        }
        return settings
    }
}

import AVFoundation

/// Metadata of the chosen video. The frames themselves are never kept in memory.
nonisolated struct ImportedVideo: Identifiable {
    enum ImportError: LocalizedError {
        case noVideoTrack
        case invalidDuration
        case invalidDimensions

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: "The file has no video track"
            case .invalidDuration: "The video has an invalid duration"
            case .invalidDimensions: "The video has invalid dimensions"
            }
        }
    }

    let id = UUID()
    let asset: AVURLAsset
    let duration: TimeInterval
    /// Size of the stored frames, before the rotation.
    let naturalSize: CGSize
    let nominalFrameRate: Float
    let preferredTransform: CGAffineTransform

    /// Size of the video as the user sees it. A vertical iPhone video is stored as
    /// landscape with a 90 degree transform, so the width and the height are swapped here.
    var displaySize: CGSize {
        let transformed = naturalSize.applying(preferredTransform)
        let size = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        return size.width > 0 && size.height > 0
            ? size
            : CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
    }

    static func load(from asset: AVURLAsset) async throws -> ImportedVideo {
        let duration = try await asset.load(.duration).seconds

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ImportError.noVideoTrack
        }
        let naturalSize = try await track.load(.naturalSize)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let preferredTransform = try await track.load(.preferredTransform)

        guard duration.isFinite, duration > 0 else { throw ImportError.invalidDuration }
        guard naturalSize.width != 0, naturalSize.height != 0 else { throw ImportError.invalidDimensions }

        return ImportedVideo(asset: asset,
                             duration: duration,
                             naturalSize: naturalSize,
                             nominalFrameRate: nominalFrameRate,
                             preferredTransform: preferredTransform)
    }
}

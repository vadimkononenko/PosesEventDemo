import AVFoundation
import Photos
import UIKit

enum MediaAssetLoadError: LocalizedError {
    case imageUnavailable
    case videoUnavailable
    case unsupportedVideo

    var errorDescription: String? {
        switch self {
        case .imageUnavailable: "Failed to load the photo"
        case .videoUnavailable: "Failed to load the video"
        case .unsupportedVideo: "This kind of video (for example slo-mo) is not supported"
        }
    }
}

/// Loads the content of an asset the user has chosen in `MediaLibraryPicker`.
enum MediaAssetLoader {
    static func loadImage(_ asset: PHAsset) async throws -> UIImage {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true // the photo may live in iCloud

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                // The data keeps the EXIF orientation, `UIImage(data:)` reads it.
                if let data, let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: MediaAssetLoadError.imageUnavailable)
                }
            }
        }
    }

    static func loadVideo(_ asset: PHAsset) async throws -> AVURLAsset {
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let avAsset else {
                    continuation.resume(throwing: MediaAssetLoadError.videoUnavailable)
                    return
                }
                // Slo-mo videos come as a composition without a file.
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: MediaAssetLoadError.unsupportedVideo)
                    return
                }
                continuation.resume(returning: urlAsset)
            }
        }
    }
}

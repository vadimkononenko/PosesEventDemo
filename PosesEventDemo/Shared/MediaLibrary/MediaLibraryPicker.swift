import Photos
import PhotosUI
import SwiftUI

/// Own picker instead of `PhotosPicker`: `PhotosPicker` shows the whole library without asking
/// for permission, here the user sees only what the app was allowed to see.
struct MediaLibraryPicker: View {
    let mediaType: PHAssetMediaType
    let onSelect: (PHAsset) -> Void

    @State private var access = PhotoLibraryAccess()
    @State private var assets: PHFetchResult<PHAsset>?
    @Environment(\.dismiss) private var dismiss

    private var title: String { mediaType == .video ? "Videos" : "Photos" }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .task {
            if access.status == .notDetermined {
                await access.requestAccess()
            }
        }
        .task(id: [access.status.rawValue, access.changeCount]) {
            reloadAssets()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch access.status {
        case .notDetermined:
            ProgressView()
        case .authorized, .limited:
            library
        case .denied, .restricted:
            ContentUnavailableView {
                Label("No access to \(title)", systemImage: "lock.shield")
            } description: {
                Text("Allow access to your library in Settings to choose \(title.lowercased()) for analysis.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        @unknown default:
            EmptyView()
        }
    }

    // MARK: Library

    private var library: some View {
        VStack(spacing: 0) {
            if access.status == .limited {
                limitedBanner
            }

            if let assets, assets.count > 0 {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                        ForEach(0..<assets.count, id: \.self) { index in
                            let asset = assets.object(at: index)
                            Button {
                                onSelect(asset)
                                dismiss()
                            } label: {
                                AssetThumbnail(asset: asset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ContentUnavailableView("No \(title.lowercased())",
                                       systemImage: mediaType == .video ? "video.slash" : "photo.on.rectangle",
                                       description: Text(access.status == .limited
                                                         ? "Use “Select more” to share some with the app."
                                                         : "Nothing found in the library."))
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private var limitedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)

            Text("Only the \(assets?.count ?? 0) \(title.lowercased()) you allowed are shown.")
                .font(.footnote)

            Spacer()

            Button("Select more") {
                if let controller = Self.topViewController() {
                    PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
                }
            }
            .font(.footnote.bold())
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private func reloadAssets() {
        guard access.canReadLibrary else {
            assets = nil
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        assets = PHAsset.fetchAssets(with: mediaType, options: options)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

private struct AssetThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if asset.mediaType == .video {
                    Text(Self.durationText(asset.duration))
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(4)
                }
            }
            .task(id: asset.localIdentifier) {
                image = await Self.loadThumbnail(for: asset)
            }
    }

    private static func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat // exactly one callback
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset,
                                                  targetSize: CGSize(width: 300, height: 300),
                                                  contentMode: .aspectFill,
                                                  options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

/// A button that opens `MediaLibraryPicker` in a sheet.
struct ChooseMediaButton: View {
    let title: String
    let systemImage: String
    let mediaType: PHAssetMediaType
    var isProminent = true
    let onSelect: (PHAsset) -> Void

    @State private var isPresented = false

    var body: some View {
        Group {
            if isProminent {
                button.buttonStyle(.borderedProminent)
            } else {
                button
            }
        }
        .sheet(isPresented: $isPresented) {
            MediaLibraryPicker(mediaType: mediaType, onSelect: onSelect)
        }
    }

    private var button: some View {
        Button {
            isPresented = true
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

import Photos
import Observation

/// Authorization state of the photo library and a signal when the library changes
/// (for example, when the user adds more photos to a limited selection).
@MainActor
@Observable
final class PhotoLibraryAccess: NSObject, @preconcurrency PHPhotoLibraryChangeObserver {
    private(set) var status: PHAuthorizationStatus
    /// Incremented on every change of the library; views reload their lists when it changes.
    private(set) var changeCount = 0

    override init() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    isolated deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    var canReadLibrary: Bool {
        status == .authorized || status == .limited
    }

    func requestAccess() async {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        changeCount += 1
    }
}

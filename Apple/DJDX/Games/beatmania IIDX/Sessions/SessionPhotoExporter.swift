import Photos
import UIKit

enum SessionPhotoExporter {
    enum ExportResult {
        case saved(Int)
        case denied
        case failed
    }

    static func save(_ images: [UIImage]) async -> ExportResult {
        guard !images.isEmpty else { return .failed }
        let status = await requestAddAuthorization()
        guard status == .authorized || status == .limited else { return .denied }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                for image in images {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            } completionHandler: { success, _ in
                continuation.resume(returning: success ? .saved(images.count) : .failed)
            }
        }
    }

    private static func requestAddAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}

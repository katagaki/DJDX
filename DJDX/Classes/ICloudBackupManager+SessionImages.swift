import CryptoKit
import Foundation

extension ICloudBackupManager {

    // MARK: Session Images

    static func updateImagesArchive(in backupFolder: URL, using fileManager: FileManager) throws -> Bool {
        let imagesURL = sessionImagesURL
        let archiveURL = backupFolder.appendingPathComponent(imagesArchiveName)
        guard fileManager.fileExists(atPath: imagesURL.path) else { return false }

        let manifest = imagesManifest(at: imagesURL, using: fileManager)
        if manifest == UserDefaults.standard.string(forKey: imagesManifestKey),
           fileManager.fileExists(atPath: archiveURL.path) {
            return false
        }

        let stagingURL = fileManager.temporaryDirectory
            .appendingPathComponent("DJDXBackup-\(UUID().uuidString)")
            .appendingPathExtension("zip")
        defer { try? fileManager.removeItem(at: stagingURL) }
        try Task.checkCancellation()
        try ZipArchive.zip(directoryAt: imagesURL, to: stagingURL)

        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }
        try fileManager.moveItem(at: stagingURL, to: archiveURL)
        UserDefaults.standard.set(manifest, forKey: imagesManifestKey)
        return true
    }

    static func imagesManifest(at directory: URL, using fileManager: FileManager) -> String {
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return "" }
        let entries = items.map { item -> String in
            let values = try? item.resourceValues(
                forKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            let size = values?.fileSize ?? 0
            let modified = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
            return "\(item.lastPathComponent):\(size):\(modified)"
        }.sorted()
        let digest = SHA256.hash(data: Data(entries.joined(separator: "\n").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func restoreImagesArchive(
        from backupFolder: URL,
        to containerURL: URL,
        using fileManager: FileManager
    ) async throws {
        let archiveURL = backupFolder.appendingPathComponent(imagesArchiveName)
        guard fileManager.fileExists(atPath: archiveURL.path) else { return }
        guard await ensureDownloaded(archiveURL, timeout: 600.0) else {
            throw BackupError.downloadTimedOut
        }

        let extractionURL = fileManager.temporaryDirectory
            .appendingPathComponent("DJDXRestore-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: extractionURL) }
        try ZipArchive.unzip(fileAt: archiveURL, to: extractionURL)

        let destination = containerURL
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let root = try unwrappedRoot(of: extractionURL, using: fileManager)
        for item in try fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.moveItem(at: item, to: target)
        }
        UserDefaults.standard.set(
            imagesManifest(at: destination, using: fileManager),
            forKey: imagesManifestKey
        )
    }

    static func unwrappedRoot(of extractionURL: URL, using fileManager: FileManager) throws -> URL {
        let items = try fileManager.contentsOfDirectory(
            at: extractionURL, includingPropertiesForKeys: [.isDirectoryKey]
        )
        if items.count == 1,
           (try? items[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return items[0]
        }
        return extractionURL
    }
}

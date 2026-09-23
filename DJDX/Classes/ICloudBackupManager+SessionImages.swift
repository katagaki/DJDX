import Foundation

extension ICloudBackupManager {

    // MARK: Session Images

    static let imagesFolderName = "Images"

    private static var imagesManifestURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ICloudBackupImagesManifest.json")
    }

    static func syncSessionImages(to backupFolder: URL, using fileManager: FileManager) throws -> Int {
        let sourceURL = sessionImagesURL
        guard fileManager.fileExists(atPath: sourceURL.path) else { return 0 }
        let destination = backupFolder.appendingPathComponent(imagesFolderName, isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        let local = imageSignatures(at: sourceURL, using: fileManager)
        var manifest = loadImagesManifest()
        manifest = manifest.filter { local[$0.key] != nil }
        defer { saveImagesManifest(manifest) }

        var changes = 0
        for (name, signature) in local where manifest[name] != signature {
            try Task.checkCancellation()
            let target = destination.appendingPathComponent(name)
            try? fileManager.removeItem(at: target)
            try fileManager.copyItem(at: sourceURL.appendingPathComponent(name), to: target)
            manifest[name] = signature
            changes += 1
        }

        let remoteItems = (try? fileManager.contentsOfDirectory(
            at: destination, includingPropertiesForKeys: nil
        )) ?? []
        for item in remoteItems {
            guard let name = cloudItemName(item.lastPathComponent), local[name] == nil else { continue }
            try? fileManager.removeItem(at: item)
            changes += 1
        }

        let legacyArchiveURL = backupFolder.appendingPathComponent(imagesArchiveName)
        if fileManager.fileExists(atPath: legacyArchiveURL.path) {
            try? fileManager.removeItem(at: legacyArchiveURL)
        }
        UserDefaults.standard.removeObject(forKey: imagesManifestKey)
        return changes
    }

    static func restoreSessionImages(
        from backupFolder: URL,
        to containerURL: URL,
        using fileManager: FileManager
    ) async throws {
        let destination = containerURL
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        let folder = backupFolder.appendingPathComponent(imagesFolderName, isDirectory: true)
        let names = ((try? fileManager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil
        )) ?? []).compactMap { cloudItemName($0.lastPathComponent) }

        if names.isEmpty {
            try await restoreLegacyImagesArchive(
                from: backupFolder, to: destination, using: fileManager
            )
        } else {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for name in names {
                try? fileManager.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(name))
            }
            let deadline = Date.now.addingTimeInterval(1800.0)
            for name in names {
                let source = folder.appendingPathComponent(name)
                guard await ensureDownloaded(source, timeout: max(1.0, deadline.timeIntervalSinceNow)) else {
                    throw BackupError.downloadTimedOut
                }
                let target = destination.appendingPathComponent(name)
                try? fileManager.removeItem(at: target)
                try fileManager.copyItem(at: source, to: target)
            }
        }
        saveImagesManifest(imageSignatures(at: destination, using: fileManager))
    }

    private static func restoreLegacyImagesArchive(
        from backupFolder: URL,
        to destination: URL,
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
    }

    // MARK: Manifest

    private static func imageSignatures(at directory: URL, using fileManager: FileManager) -> [String: String] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return [:] }
        var signatures: [String: String] = [:]
        for item in items {
            guard let values = try? item.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            let size = values.fileSize ?? 0
            let modified = Int(values.contentModificationDate?.timeIntervalSince1970 ?? 0)
            signatures[item.lastPathComponent] = "\(size):\(modified)"
        }
        return signatures
    }

    private static func cloudItemName(_ fileName: String) -> String? {
        if fileName.hasPrefix("."), fileName.hasSuffix(".icloud") {
            return String(fileName.dropFirst().dropLast(".icloud".count))
        }
        return fileName.hasPrefix(".") ? nil : fileName
    }

    private static func loadImagesManifest() -> [String: String] {
        guard let url = imagesManifestURL,
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return manifest
    }

    private static func saveImagesManifest(_ manifest: [String: String]) {
        guard let url = imagesManifestURL,
              let data = try? JSONEncoder().encode(manifest) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
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

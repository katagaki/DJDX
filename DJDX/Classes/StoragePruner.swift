import Foundation
import WebKit

struct StorageEntry: Sendable {
    let path: String
    let bytes: Int64
}

struct StorageReport: Sendable {
    var temporaryFiles: Int64 = 0
    var caches: Int64 = 0
    var webData: Int64 = 0
    var orphanedSessionImages: Int64 = 0

    var total: Int64 = 0
    var largest: [StorageEntry] = []

    var freed: Int64 { temporaryFiles + caches + webData + orphanedSessionImages }
}

enum StoragePruner {

    static func prune() async -> StorageReport {
        let webKitBefore = await Task.detached(priority: .utility) { sizeOfWebKitDirectory() }.value
        let cachedResponses = await MainActor.run { Int64(URLCache.shared.currentDiskUsage) }
        await clearWebData()

        return await Task.detached(priority: .utility) { () -> StorageReport in
            var report = StorageReport()
            report.temporaryFiles = emptyDirectory(FileManager.default.temporaryDirectory)
            report.caches = emptyDirectory(cachesDirectory())
            report.orphanedSessionImages = removeOrphanedSessionImages()
            report.webData = max(0, webKitBefore - sizeOfWebKitDirectory()) + cachedResponses

            let survey = surveyStorage()
            report.total = survey.total
            report.largest = survey.largest
            return report
        }.value
    }

    // MARK: Web data

    @MainActor
    private static func clearWebData() async {
        URLCache.shared.removeAllCachedResponses()
        let types: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeServiceWorkerRegistrations
        ]
        await WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast)
    }

    private static func sizeOfWebKitDirectory() -> Int64 {
        guard let library = FileManager.default.urls(
            for: .libraryDirectory, in: .userDomainMask
        ).first else { return 0 }
        return size(of: library.appendingPathComponent("WebKit", isDirectory: true))
    }

    // MARK: Orphaned session images

    private static func removeOrphanedSessionImages() -> Int64 {
        let fileManager = FileManager.default
        let directory = sessionImagesDirectory()
        guard let referenced = IIDXPlaySessionsDatabase.shared.referencedImageFilenames(),
              let items = try? fileManager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
              ) else { return 0 }

        let referencedIDs = Set(referenced.map { ($0 as NSString).deletingPathExtension })
        let cutoff = Date.now.addingTimeInterval(-3600.0)
        var reclaimed: Int64 = 0
        for item in items {
            let name = item.lastPathComponent
            let id = name.hasSuffix(".ocr.json")
                ? String(name.dropLast(9))
                : (name as NSString).deletingPathExtension
            guard !referencedIDs.contains(id) else { continue }
            let modified = try? item.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate
            guard let modified, modified < cutoff else { continue }
            let itemSize = size(of: item)
            if (try? fileManager.removeItem(at: item)) != nil {
                reclaimed += itemSize
            }
        }
        return reclaimed
    }

    // MARK: Directories

    private static func cachesDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    private static func sessionImagesDirectory() -> URL {
        SharedContainer.containerURL
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
    }

    // MARK: Survey

    private static func surveyStorage() -> (total: Int64, largest: [StorageEntry]) {
        let roots: [(String, URL)] = [
            ("App", URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)),
            ("Group", SharedContainer.containerURL)
        ]
        var entries: [StorageEntry] = []
        var total: Int64 = 0
        for (label, root) in roots {
            let branches = survey(root, label: label, depth: 2)
            total += branches.total
            entries.append(contentsOf: branches.entries)
        }
        let largest = entries
            .filter { $0.bytes >= 1_048_576 }
            .sorted { $0.bytes > $1.bytes }
            .prefix(8)
        return (total, Array(largest))
    }

    private static func survey(_ directory: URL, label: String, depth: Int) -> (
        total: Int64, entries: [StorageEntry]
    ) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            let bytes = size(of: directory)
            return (bytes, [StorageEntry(path: label, bytes: bytes)])
        }
        var total: Int64 = 0
        var entries: [StorageEntry] = []
        for item in items {
            let name = "\(label)/\(item.lastPathComponent)"
            let isDirectory = (try? item.resourceValues(
                forKeys: [.isDirectoryKey]
            ).isDirectory) == true
            if isDirectory, depth > 1 {
                let branch = survey(item, label: name, depth: depth - 1)
                total += branch.total
                entries.append(contentsOf: branch.entries)
            } else {
                let bytes = size(of: item)
                total += bytes
                entries.append(StorageEntry(path: name, bytes: bytes))
            }
        }
        return (total, entries)
    }

    private static func emptyDirectory(_ directory: URL) -> Int64 {
        let fileManager = FileManager.default
        let resolved = directory.resolvingSymlinksInPath()
        guard let items = try? fileManager.contentsOfDirectory(
            at: resolved, includingPropertiesForKeys: nil
        ) else { return 0 }
        var reclaimed: Int64 = 0
        for item in items {
            let target = item.resolvingSymlinksInPath()
            guard target.deletingLastPathComponent().path == resolved.path else { continue }
            let itemSize = size(of: target)
            if (try? fileManager.removeItem(at: target)) != nil {
                reclaimed += itemSize
            }
        }
        return reclaimed
    }

    // MARK: Sizing

    private static let sizeKeys: [URLResourceKey] = [
        .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
    ]

    private static func size(of url: URL) -> Int64 {
        func fileSize(_ fileURL: URL) -> Int64 {
            guard let values = try? fileURL.resourceValues(forKeys: Set(sizeKeys)),
                  values.isRegularFile == true else { return 0 }
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            var total: Int64 = 0
            if let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: sizeKeys
            ) {
                for case let child as URL in enumerator {
                    total += fileSize(child)
                }
            }
            return total
        }
        return fileSize(url)
    }
}

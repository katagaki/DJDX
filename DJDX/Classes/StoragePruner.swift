import Foundation
import WebKit

struct StorageReport: Sendable {
    var temporaryFiles: Int64 = 0
    var caches: Int64 = 0
    var webData: Int64 = 0
    var orphanedSessionImages: Int64 = 0

    var sessionImages: Int64 = 0
    var documents: Int64 = 0
    var databases: Int64 = 0

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

            report.sessionImages = size(of: sessionImagesDirectory())
            report.documents = size(of: documentsDirectory())
            report.databases = sizeOfDatabases()
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

    private static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    private static func sessionImagesDirectory() -> URL {
        SharedContainer.containerURL
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
    }

    private static func sizeOfDatabases() -> Int64 {
        let fileManager = FileManager.default
        let container = SharedContainer.containerURL
        guard let items = try? fileManager.contentsOfDirectory(
            at: container, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return 0 }
        var total: Int64 = 0
        for item in items where item.lastPathComponent != "Sessions" {
            total += size(of: item)
        }
        return total
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

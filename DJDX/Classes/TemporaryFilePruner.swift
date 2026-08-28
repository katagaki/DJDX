import Foundation

enum TemporaryFilePruner {

    static let prefixes: [String] = [
        "Export-",
        "DJDXBackup-",
        "DJDXStaging-",
        "DJDXRestore-",
        "SessionExport-"
    ]

    static func prune() async -> Int64 {
        await Task.detached(priority: .utility) { () -> Int64 in
            let fileManager = FileManager.default
            let temporaryDirectory = fileManager.temporaryDirectory.resolvingSymlinksInPath()
            guard let items = try? fileManager.contentsOfDirectory(
                at: temporaryDirectory, includingPropertiesForKeys: nil
            ) else { return 0 }

            var reclaimed: Int64 = 0
            for item in items {
                let name = item.lastPathComponent
                guard prefixes.contains(where: { name.hasPrefix($0) }) else { continue }
                let resolved = item.resolvingSymlinksInPath()
                guard resolved.deletingLastPathComponent().path == temporaryDirectory.path else { continue }
                let size = sizeOfItem(at: resolved, using: fileManager)
                if (try? fileManager.removeItem(at: resolved)) != nil {
                    reclaimed += size
                }
            }
            return reclaimed
        }.value
    }

    private static func sizeOfItem(at url: URL, using fileManager: FileManager) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        func size(of fileURL: URL) -> Int64 {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { return 0 }
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            var total: Int64 = 0
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys) {
                for case let child as URL in enumerator {
                    total += size(of: child)
                }
            }
            return total
        }
        return size(of: url)
    }
}

import Foundation

extension ICloudBackupManager {

    // MARK: Settings Snapshot

    static func writeDefaultsSnapshot(to containerURL: URL) {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let domain = UserDefaults.standard.persistentDomain(forName: bundleID),
              let data = try? PropertyListSerialization.data(
                fromPropertyList: domain, format: .binary, options: 0
              ) else { return }
        try? data.write(
            to: containerURL.appendingPathComponent(defaultsSnapshotName),
            options: .atomic
        )
    }

    static func applyDefaultsSnapshot(from containerURL: URL) {
        let snapshotURL = containerURL.appendingPathComponent(defaultsSnapshotName)
        guard let data = try? Data(contentsOf: snapshotURL),
              let domain = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil
              ) as? [String: Any] else { return }
        for (key, value) in domain {
            UserDefaults.standard.set(value, forKey: key)
        }
    }
}

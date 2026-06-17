import Foundation

enum DataMigration {

    static let version334CleanupKey = "Internal.Version334Cleanup"

    private static let databaseFileNames = [
        "PlayData.db",
        "PlayDataDDR.db",
        "PlayDataSDVX.db",
        "PlayDataPolarisChord.db",
        "ExD_BEMANIWiki.db",
        "ExD_Textage.db",
        "ExD_SDVXIn.db",
        "ExD_BM2DX.db",
        "ExD_DDR.db"
    ]

    private static let radarKeys: [String] = {
        let playTypes = ["SP", "DP"]
        let metrics = ["Notes", "Chord", "Peak", "Charge", "Scratch", "Soflan"]
        return playTypes.flatMap { playType in metrics.map { "NotesRadar.\(playType).\($0)" } }
    }()

    static func runVersion334CleanupIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: version334CleanupKey) else { return }

        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let containerURL = SharedContainer.containerURL

        for name in databaseFileNames {
            for suffix in ["", "-wal", "-shm"] {
                moveIfPossible(
                    from: documentsURL.appendingPathComponent(name + suffix),
                    to: containerURL.appendingPathComponent(name + suffix)
                )
            }
        }

        moveImages(from: documentsURL, to: SharedContainer.imagesURL)
        migrateDefaults()

        try? fileManager.removeItem(at: SharedContainer.widgetDataURL)

        UserDefaults.standard.set(true, forKey: version334CleanupKey)
    }

    static func moveImages(from source: URL, to imagesDirectory: URL) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: nil
        ) else { return }
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        for fileURL in contents where fileURL.pathExtension.lowercased() == "png" {
            moveIfPossible(from: fileURL, to: imagesDirectory.appendingPathComponent(fileURL.lastPathComponent))
        }
    }

    private static func migrateDefaults() {
        let standard = UserDefaults.standard
        let shared = SharedContainer.defaults
        for key in radarKeys where standard.object(forKey: key) != nil {
            shared.set(standard.double(forKey: key), forKey: key)
        }
        shared.set(standard.integer(forKey: "Global.IIDX.Version"), forKey: WidgetConfig.versionKey)
        shared.set(
            standard.string(forKey: "ScoresView.PlayTypeFilter") ?? "single",
            forKey: WidgetConfig.playTypeKey
        )
    }

    private static func moveIfPossible(from source: URL, to destination: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path),
              !fileManager.fileExists(atPath: destination.path) else { return }
        try? fileManager.moveItem(at: source, to: destination)
    }
}

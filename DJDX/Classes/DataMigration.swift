import Foundation
import SQLite

enum DataMigration {

    static let version334CleanupKey = "Internal.Version334Cleanup"
    static let bemaniWikiLevelsKey = "Internal.BEMANIWikiLevels"

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

    // Adds the per-chart level columns to an existing BEMANIWiki database so the
    // next data reload can populate them (fresh installs already have them). Plays
    // are backfilled from those levels during the reload itself.
    static func runBEMANIWikiLevelsMigrationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: bemaniWikiLevelsKey) else { return }
        if let database = try? BEMANIWikiDatabase.shared.getWriteConnection() {
            let col = BEMANIWikiDatabase.self
            let columns = [
                col.songSPBeginnerLevel, col.songSPNormalLevel, col.songSPHyperLevel,
                col.songSPAnotherLevel, col.songSPLeggendariaLevel,
                col.songDPNormalLevel, col.songDPHyperLevel,
                col.songDPAnotherLevel, col.songDPLeggendariaLevel
            ]
            for column in columns {
                _ = try? database.run(col.songTable.addColumn(column))
            }
        }
        UserDefaults.standard.set(true, forKey: bemaniWikiLevelsKey)
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

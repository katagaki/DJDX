import Foundation
import SQLite

final class PolarisChordPlayDataDatabase: Sendable {

    static let shared = PolarisChordPlayDataDatabase()

    let databasePath: String

    // MARK: - ImportGroup Table

    static let importGroupTable = Table("PolarisChordImportGroup")
    static let igID = SQLite.Expression<String>("id")
    static let igImportDate = SQLite.Expression<Double>("importDate")
    static let igVersion = SQLite.Expression<Int?>("version")

    // MARK: - PolarisChordSongRecord Table

    static let songRecordTable = Table("PolarisChordSongRecord")
    static let srID = SQLite.Expression<Int64>("id")
    static let srImportGroupID = SQLite.Expression<String>("importGroupID")
    static let srTitle = SQLite.Expression<String>("title")
    static let srMusicID = SQLite.Expression<String>("musicID")
    static let srCategory = SQLite.Expression<String>("category")
    static let srDifficulty = SQLite.Expression<String>("difficulty")
    static let srLevel = SQLite.Expression<String>("level")
    static let srAchievementRate = SQLite.Expression<String>("achievementRate")
    static let srScore = SQLite.Expression<Int>("score")
    static let srClearType = SQLite.Expression<String>("clearType")
    static let srGrade = SQLite.Expression<String>("grade")

    // MARK: - Initialization

    init(fileName: String = "PlayDataPolarisChord.db") {
        databasePath = SharedContainer.containerURL.appendingPathComponent(fileName).path
        createTablesIfNeeded()
    }

    // MARK: - Connection

    func getReadConnection() throws -> Connection {
        try Connection(databasePath, readonly: true)
    }

    func getWriteConnection() throws -> Connection {
        try Connection(databasePath)
    }

    // MARK: - Table Creation

    private func createTablesIfNeeded() {
        do {
            let database = try Connection(databasePath)

            try database.run(Self.importGroupTable.create(ifNotExists: true) { table in
                table.column(Self.igID, primaryKey: true)
                table.column(Self.igImportDate)
                table.column(Self.igVersion)
            })

            try database.run(Self.songRecordTable.create(ifNotExists: true) { table in
                table.column(Self.srID, primaryKey: .autoincrement)
                table.column(Self.srImportGroupID)
                table.column(Self.srTitle, defaultValue: "")
                table.column(Self.srMusicID, defaultValue: "")
                table.column(Self.srCategory, defaultValue: "")
                table.column(Self.srDifficulty, defaultValue: "")
                table.column(Self.srLevel, defaultValue: "")
                table.column(Self.srAchievementRate, defaultValue: "")
                table.column(Self.srScore, defaultValue: 0)
                table.column(Self.srClearType, defaultValue: "NO PLAY")
                table.column(Self.srGrade, defaultValue: "---")
            })

            // Ensure the score column exists on tables created before the rename.
            _ = try? database.run(Self.songRecordTable.addColumn(Self.srScore, defaultValue: 0))

            try database.run(Self.songRecordTable.createIndex(
                Self.srImportGroupID,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create Polaris Chord tables: \(error)")
        }
    }
}

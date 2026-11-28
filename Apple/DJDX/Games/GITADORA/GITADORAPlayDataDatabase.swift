import Foundation
import SQLite

final class GITADORAPlayDataDatabase: Sendable {

    static let shared = GITADORAPlayDataDatabase()

    let databasePath: String

    // MARK: - ImportGroup Table

    static let importGroupTable = Table("GITADORAImportGroup")
    static let igID = SQLite.Expression<String>("id")
    static let igImportDate = SQLite.Expression<Double>("importDate")
    static let igVersion = SQLite.Expression<Int?>("version")

    // MARK: - GITADORASongRecord Table

    static let songRecordTable = Table("GITADORASongRecord")
    static let srID = SQLite.Expression<Int64>("id")
    static let srImportGroupID = SQLite.Expression<String>("importGroupID")
    static let srTitle = SQLite.Expression<String>("title")
    static let srInstrument = SQLite.Expression<String>("instrument")
    static let srDifficulty = SQLite.Expression<String>("difficulty")
    static let srLevel = SQLite.Expression<String>("level")
    static let srAchievementRate = SQLite.Expression<String>("achievementRate")
    static let srScore = SQLite.Expression<Int>("score")
    static let srClearType = SQLite.Expression<String>("clearType")
    static let srRank = SQLite.Expression<String>("rank")

    // MARK: - Initialization

    init(fileName: String = "PlayDataGITADORA.db") {
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
                table.column(Self.srInstrument, defaultValue: "")
                table.column(Self.srDifficulty, defaultValue: "")
                table.column(Self.srLevel, defaultValue: "")
                table.column(Self.srAchievementRate, defaultValue: "")
                table.column(Self.srScore, defaultValue: 0)
                table.column(Self.srClearType, defaultValue: "NO PLAY")
                table.column(Self.srRank, defaultValue: "---")
            })

            try database.run(Self.songRecordTable.createIndex(
                Self.srImportGroupID,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create GITADORA tables: \(error)")
        }
    }
}

import Foundation
import SQLite

final class DDRPlayDataDatabase: Sendable {

    static let shared = DDRPlayDataDatabase()

    let databasePath: String

    // MARK: - ImportGroup Table

    static let importGroupTable = Table("DDRImportGroup")
    static let igID = SQLite.Expression<String>("id")
    static let igImportDate = SQLite.Expression<Double>("importDate")
    static let igVersion = SQLite.Expression<Int?>("version")

    // MARK: - DDRSongRecord Table

    static let songRecordTable = Table("DDRSongRecord")
    static let srID = SQLite.Expression<Int64>("id")
    static let srImportGroupID = SQLite.Expression<String>("importGroupID")
    static let srSongIndex = SQLite.Expression<String>("songIndex")
    static let srTitle = SQLite.Expression<String>("title")
    static let srStyle = SQLite.Expression<String>("style")
    static let srDifficulty = SQLite.Expression<String>("difficulty")
    static let srLevel = SQLite.Expression<Int>("level")
    static let srScore = SQLite.Expression<Int>("score")
    static let srRank = SQLite.Expression<String>("rank")
    static let srClearKind = SQLite.Expression<String>("clearKind")
    static let srFlareSkill = SQLite.Expression<Int>("flareSkill")
    static let srFlareRank = SQLite.Expression<String>("flareRank")
    static let srJacketPath = SQLite.Expression<String>("jacketPath")

    // MARK: - Initialization

    init(fileName: String = "PlayDataDDR.db") {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        databasePath = documentsURL.appendingPathComponent(fileName).path
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
                table.column(Self.srSongIndex, defaultValue: "")
                table.column(Self.srTitle, defaultValue: "")
                table.column(Self.srStyle, defaultValue: "")
                table.column(Self.srDifficulty, defaultValue: "")
                table.column(Self.srLevel, defaultValue: 0)
                table.column(Self.srScore, defaultValue: 0)
                table.column(Self.srRank, defaultValue: "")
                table.column(Self.srClearKind, defaultValue: "")
                table.column(Self.srFlareSkill, defaultValue: 0)
                table.column(Self.srFlareRank, defaultValue: "")
                table.column(Self.srJacketPath, defaultValue: "")
            })

            try database.run(Self.songRecordTable.createIndex(
                Self.srImportGroupID,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create DDR tables: \(error)")
        }
    }
}

import Foundation
import SQLite

final class SDVXPlayDataDatabase: Sendable {

    static let shared = SDVXPlayDataDatabase()

    let databasePath: String

    // MARK: - ImportGroup Table

    static let importGroupTable = Table("SDVXImportGroup")
    static let igID = SQLite.Expression<String>("id")
    static let igImportDate = SQLite.Expression<Double>("importDate")
    static let igVersion = SQLite.Expression<Int?>("version")

    // MARK: - SDVXSongRecord Table

    static let songRecordTable = Table("SDVXSongRecord")
    static let srID = SQLite.Expression<Int64>("id")
    static let srImportGroupID = SQLite.Expression<String>("importGroupID")
    static let srTitle = SQLite.Expression<String>("title")
    static let srDifficulty = SQLite.Expression<String>("difficulty")
    static let srLevel = SQLite.Expression<String>("level")
    static let srClearType = SQLite.Expression<String>("clearType")
    static let srGrade = SQLite.Expression<String>("grade")
    static let srHighScore = SQLite.Expression<Int>("highScore")
    static let srEXScore = SQLite.Expression<Int>("exScore")
    static let srPlayCount = SQLite.Expression<Int>("playCount")
    static let srClearCount = SQLite.Expression<Int>("clearCount")
    static let srUltimateChainCount = SQLite.Expression<Int>("ultimateChainCount")
    static let srPerfectCount = SQLite.Expression<Int>("perfectCount")

    // MARK: - Initialization

    init(fileName: String = "PlayDataSDVX.db") {
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
                table.column(Self.srTitle, defaultValue: "")
                table.column(Self.srDifficulty, defaultValue: "")
                table.column(Self.srLevel, defaultValue: "")
                table.column(Self.srClearType, defaultValue: "NO PLAY")
                table.column(Self.srGrade, defaultValue: "---")
                table.column(Self.srHighScore, defaultValue: 0)
                table.column(Self.srEXScore, defaultValue: 0)
                table.column(Self.srPlayCount, defaultValue: 0)
                table.column(Self.srClearCount, defaultValue: 0)
                table.column(Self.srUltimateChainCount, defaultValue: 0)
                table.column(Self.srPerfectCount, defaultValue: 0)
            })

            try database.run(Self.songRecordTable.createIndex(
                Self.srImportGroupID,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create SDVX tables: \(error)")
        }
    }
}

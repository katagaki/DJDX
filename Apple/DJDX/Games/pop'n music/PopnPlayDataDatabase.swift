import Foundation
import SQLite

final class PopnPlayDataDatabase: Sendable {

    static let shared = PopnPlayDataDatabase()

    let databasePath: String

    // MARK: - ImportGroup Table

    static let importGroupTable = Table("PopnImportGroup")
    static let igID = SQLite.Expression<String>("id")
    static let igImportDate = SQLite.Expression<Double>("importDate")
    static let igVersion = SQLite.Expression<Int?>("version")

    // MARK: - PopnSongRecord Table

    static let songRecordTable = Table("PopnSongRecord")
    static let srID = SQLite.Expression<Int64>("id")
    static let srImportGroupID = SQLite.Expression<String>("importGroupID")
    static let srTitle = SQLite.Expression<String>("title")
    static let srGenre = SQLite.Expression<String>("genre")
    static let srArtist = SQLite.Expression<String>("artist")
    static let srDifficulty = SQLite.Expression<String>("difficulty")
    static let srLevel = SQLite.Expression<Int>("level")
    static let srScore = SQLite.Expression<Int>("score")
    static let srMedal = SQLite.Expression<String>("medal")
    static let srRank = SQLite.Expression<String>("rank")

    // MARK: - Initialization

    init(fileName: String = "PlayDataPopn.db") {
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
                table.column(Self.srGenre, defaultValue: "")
                table.column(Self.srArtist, defaultValue: "")
                table.column(Self.srDifficulty, defaultValue: "")
                table.column(Self.srLevel, defaultValue: 0)
                table.column(Self.srScore, defaultValue: 0)
                table.column(Self.srMedal, defaultValue: PopnMedal.noPlay.rawValue)
                table.column(Self.srRank, defaultValue: PopnRank.none.rawValue)
            })

            try database.run(Self.songRecordTable.createIndex(
                Self.srImportGroupID,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create pop'n music tables: \(error)")
        }
    }
}

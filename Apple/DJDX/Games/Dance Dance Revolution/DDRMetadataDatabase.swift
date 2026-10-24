import Foundation
import SQLite

final class DDRMetadataDatabase: Sendable {

    static let shared = DDRMetadataDatabase()

    let databasePath: String

    // MARK: - DDRSongMeta Table

    static let songMetaTable = Table("DDRSongMeta")
    static let smTitleCompact = SQLite.Expression<String>("titleCompact")
    static let smTitle = SQLite.Expression<String>("title")
    static let smVersion = SQLite.Expression<Int>("version")
    static let smSPBeginner = SQLite.Expression<Int>("spBeginner")
    static let smSPBasic = SQLite.Expression<Int>("spBasic")
    static let smSPDifficult = SQLite.Expression<Int>("spDifficult")
    static let smSPExpert = SQLite.Expression<Int>("spExpert")
    static let smSPChallenge = SQLite.Expression<Int>("spChallenge")
    static let smDPBasic = SQLite.Expression<Int>("dpBasic")
    static let smDPDifficult = SQLite.Expression<Int>("dpDifficult")
    static let smDPExpert = SQLite.Expression<Int>("dpExpert")
    static let smDPChallenge = SQLite.Expression<Int>("dpChallenge")

    // MARK: - Initialization

    private init() {
        databasePath = SharedContainer.containerURL.appendingPathComponent("ExD_DDR.db").path
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
            try database.run(Self.songMetaTable.create(ifNotExists: true) { table in
                table.column(Self.smTitleCompact, primaryKey: true)
                table.column(Self.smTitle, defaultValue: "")
                table.column(Self.smVersion, defaultValue: 0)
                table.column(Self.smSPBeginner, defaultValue: 0)
                table.column(Self.smSPBasic, defaultValue: 0)
                table.column(Self.smSPDifficult, defaultValue: 0)
                table.column(Self.smSPExpert, defaultValue: 0)
                table.column(Self.smSPChallenge, defaultValue: 0)
                table.column(Self.smDPBasic, defaultValue: 0)
                table.column(Self.smDPDifficult, defaultValue: 0)
                table.column(Self.smDPExpert, defaultValue: 0)
                table.column(Self.smDPChallenge, defaultValue: 0)
            })
        } catch {
            debugPrint("Failed to create DDR metadata tables: \(error)")
        }
    }
}

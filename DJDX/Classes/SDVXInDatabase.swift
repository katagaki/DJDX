import Foundation
import SQLite

final class SDVXInDatabase: Sendable {

    static let shared = SDVXInDatabase()

    let databasePath: String

    // MARK: - SDVXInChart Table

    static let chartTable = Table("SDVXInChart")
    static let chartID = SQLite.Expression<Int64>("id")
    static let chartCode = SQLite.Expression<String>("code")
    static let chartSlot = SQLite.Expression<String>("slot")
    static let chartTitle = SQLite.Expression<String>("title")
    static let chartTitleCompact = SQLite.Expression<String>("titleCompact")
    static let chartLevel = SQLite.Expression<Int>("level")

    // MARK: - Initialization

    private init() {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainer.appGroupID
        ) {
            databasePath = containerURL.appendingPathComponent("ExD_SDVXIn.db").path
        } else {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            databasePath = documentsURL.appendingPathComponent("ExD_SDVXIn.db").path
        }
        createTablesIfNeeded()
    }

    // MARK: - Connection

    func getReadConnection() throws -> Connection {
        let connection = try Connection(databasePath, readonly: true)
        return connection
    }

    func getWriteConnection() throws -> Connection {
        let connection = try Connection(databasePath)
        return connection
    }

    // MARK: - Table Creation

    private func createTablesIfNeeded() {
        do {
            let database = try Connection(databasePath)

            try database.run(Self.chartTable.create(ifNotExists: true) { table in
                table.column(Self.chartID, primaryKey: .autoincrement)
                table.column(Self.chartCode, defaultValue: "")
                table.column(Self.chartSlot, defaultValue: "")
                table.column(Self.chartTitle, defaultValue: "")
                table.column(Self.chartTitleCompact, defaultValue: "")
                table.column(Self.chartLevel, defaultValue: 0)
            })

            try database.run(Self.chartTable.createIndex(
                Self.chartTitleCompact, Self.chartSlot,
                unique: true,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create SDVXIn tables: \(error)")
        }
    }
}

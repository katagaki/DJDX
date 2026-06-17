import Foundation
import SQLite

final class TextageDatabase: Sendable {

    static let shared = TextageDatabase()

    let databasePath: String

    // MARK: - TextageChart Table

    static let chartTable = Table("TextageChart")
    static let chartID = SQLite.Expression<Int64>("id")
    static let chartTag = SQLite.Expression<String>("tag")
    static let chartVersion = SQLite.Expression<Int>("version")
    static let chartTitle = SQLite.Expression<String>("title")
    static let chartTitleCompact = SQLite.Expression<String>("titleCompact")
    static let chartSPNormal = SQLite.Expression<Int>("spNormal")
    static let chartSPHyper = SQLite.Expression<Int>("spHyper")
    static let chartSPAnother = SQLite.Expression<Int>("spAnother")
    static let chartSPLeggendaria = SQLite.Expression<Int>("spLeggendaria")
    static let chartDPNormal = SQLite.Expression<Int>("dpNormal")
    static let chartDPHyper = SQLite.Expression<Int>("dpHyper")
    static let chartDPAnother = SQLite.Expression<Int>("dpAnother")
    static let chartDPLeggendaria = SQLite.Expression<Int>("dpLeggendaria")

    // MARK: - Initialization

    private init() {
        databasePath = SharedContainer.containerURL.appendingPathComponent("ExD_Textage.db").path
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
                table.column(Self.chartTag, defaultValue: "")
                table.column(Self.chartVersion, defaultValue: 0)
                table.column(Self.chartTitle, defaultValue: "")
                table.column(Self.chartTitleCompact, defaultValue: "")
                table.column(Self.chartSPNormal, defaultValue: 0)
                table.column(Self.chartSPHyper, defaultValue: 0)
                table.column(Self.chartSPAnother, defaultValue: 0)
                table.column(Self.chartSPLeggendaria, defaultValue: 0)
                table.column(Self.chartDPNormal, defaultValue: 0)
                table.column(Self.chartDPHyper, defaultValue: 0)
                table.column(Self.chartDPAnother, defaultValue: 0)
                table.column(Self.chartDPLeggendaria, defaultValue: 0)
            })

            try database.run(Self.chartTable.createIndex(
                Self.chartTitleCompact,
                unique: true,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create Textage tables: \(error)")
        }
    }
}

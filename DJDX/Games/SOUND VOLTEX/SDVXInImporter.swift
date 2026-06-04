import Foundation
import SQLite

// Writes the sdvx.in chart index into SDVXInDatabase.
actor SDVXInImporter {

    typealias DB = SDVXInDatabase

    // Replaces the entire chart index in a single transaction.
    func replaceAllCharts(_ charts: [SDVXInChart]) {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        try? database.transaction {
            _ = try? database.run(DB.chartTable.delete())
            for chart in charts {
                _ = try? database.run(DB.chartTable.insert(
                    or: .replace,
                    DB.chartCode <- chart.code,
                    DB.chartSlot <- chart.slot,
                    DB.chartTitle <- chart.title,
                    DB.chartTitleCompact <- chart.title.compact,
                    DB.chartLevel <- chart.level
                ))
            }
        }
    }

    func deleteAllCharts() {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        _ = try? database.run(DB.chartTable.delete())
    }
}

import Foundation
import SQLite

actor TextageChartViewerImporter {

    // swiftlint:disable:next type_name
    typealias DB = TextageChartViewerDatabase

    func replaceAllCharts(_ charts: [TextageChartViewerChart]) {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        try? database.transaction {
            _ = try? database.run(DB.chartTable.delete())
            for chart in charts {
                _ = try? database.run(DB.chartTable.insert(
                    or: .replace,
                    DB.chartSongId <- chart.songId,
                    DB.chartVersion <- chart.version,
                    DB.chartTitle <- chart.title,
                    DB.chartTitleCompact <- chart.title.compact,
                    DB.chartSPBeginner <- chart.spBeginner,
                    DB.chartSPNormal <- chart.spNormal,
                    DB.chartSPHyper <- chart.spHyper,
                    DB.chartSPAnother <- chart.spAnother,
                    DB.chartSPLeggendaria <- chart.spLeggendaria,
                    DB.chartDPBeginner <- chart.dpBeginner,
                    DB.chartDPNormal <- chart.dpNormal,
                    DB.chartDPHyper <- chart.dpHyper,
                    DB.chartDPAnother <- chart.dpAnother,
                    DB.chartDPLeggendaria <- chart.dpLeggendaria
                ))
            }
        }
    }

    func deleteAllCharts() {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        _ = try? database.run(DB.chartTable.delete())
    }
}

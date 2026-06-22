import OrderedCollections
import SwiftUI

@MainActor
@Observable
final class DDRAnalyticsModel {

    var clearTypePerDifficulty: [DDRDifficulty: OrderedDictionary<String, Int>] = [:]
    var rankPerDifficulty: [DDRDifficulty: OrderedDictionary<String, Int>] = [:]
    var clearTypePerLevel: [Int: OrderedDictionary<String, Int>] = [:]
    var rankPerLevel: [Int: OrderedDictionary<String, Int>] = [:]

    var totalCharts: Int = 0

    var dataState: DataState = .initializing

    let fetcher = DDRReader()

    func reload(version: DDRVersion, style: DDRPlayStyle) async {
        dataState = .loading
        let records = await fetcher.latestSongRecords(for: version)
            .filter { $0.styleEnum == style }

        var clearByDiff: [DDRDifficulty: OrderedDictionary<String, Int>] = [:]
        var rankByDiff: [DDRDifficulty: OrderedDictionary<String, Int>] = [:]
        var clearByLevel: [Int: OrderedDictionary<String, Int>] = [:]
        var rankByLevel: [Int: OrderedDictionary<String, Int>] = [:]

        let clearKeys = DDRSongRecord.clearLampOrder
        let breakdownKeys = DDRSongRecord.clearBreakdownOrder
        let rankKeys = DDRSongRecord.rankOrder

        func emptyClearCounts() -> OrderedDictionary<String, Int> {
            OrderedDictionary(uniqueKeys: breakdownKeys, values: breakdownKeys.map { _ in 0 })
        }
        func emptyRankCounts() -> OrderedDictionary<String, Int> {
            OrderedDictionary(uniqueKeys: rankKeys, values: rankKeys.map { _ in 0 })
        }

        for record in records {
            let difficulty = record.difficultyEnum

            if clearByDiff[difficulty] == nil { clearByDiff[difficulty] = emptyClearCounts() }
            if rankByDiff[difficulty] == nil { rankByDiff[difficulty] = emptyRankCounts() }

            let clearBucket: String? = clearKeys.contains(record.clearKind)
                ? record.clearKind
                : (record.hasScore ? DDRSongRecord.noClearKey : nil)

            if let clearBucket {
                clearByDiff[difficulty]?[clearBucket]? += 1
            }
            if rankKeys.contains(record.rank) {
                rankByDiff[difficulty]?[record.rank]? += 1
                if record.level > 0 {
                    if rankByLevel[record.level] == nil { rankByLevel[record.level] = emptyRankCounts() }
                    rankByLevel[record.level]?[record.rank]? += 1
                }
            }

            if record.level > 0, let clearBucket {
                if clearByLevel[record.level] == nil { clearByLevel[record.level] = emptyClearCounts() }
                clearByLevel[record.level]?[clearBucket]? += 1
            }
        }

        let chartCount = records.count

        withAnimation(.smooth.speed(2.0)) {
            self.clearTypePerDifficulty = clearByDiff
            self.rankPerDifficulty = rankByDiff
            self.clearTypePerLevel = clearByLevel
            self.rankPerLevel = rankByLevel
            self.totalCharts = chartCount
            self.dataState = .presenting
        }
    }
}

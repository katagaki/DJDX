import OrderedCollections
import SwiftUI

@MainActor
@Observable
final class SDVXAnalyticsModel {

    // Clear-type counts per difficulty category (NOV/ADV/EXH/MXM/INF-tier)
    var clearTypePerDifficulty: [SDVXDifficulty: OrderedDictionary<String, Int>] = [:]
    // Grade counts per difficulty category
    var gradePerDifficulty: [SDVXDifficulty: OrderedDictionary<String, Int>] = [:]
    // Counts per integer level (4...20)
    var clearTypePerLevel: [Int: OrderedDictionary<String, Int>] = [:]

    var totalCharts: Int = 0
    var totalPlays: Int = 0
    var volforce: Double = 0.0

    var dataState: DataState = .initializing

    let fetcher = SDVXReader()

    // VOLFORCE per chart: floor(level * grade_coef * clear_coef * 2) / 100, summed over best 50.
    // Score-based single-chart force ~= level * 2 * (score / 10_000_000) as an approximation.
    private func chartForce(_ record: SDVXSongRecord) -> Double {
        let levelValue = Double(record.level) ?? 0.0
        guard levelValue > 0, record.highScore > 0 else { return 0.0 }
        return levelValue * 2.0 * (Double(record.highScore) / 10_000_000.0)
    }

    func reload(version: SDVXVersion) async {
        dataState = .loading
        let records = await fetcher.latestSongRecords(for: version)

        var clearByDiff: [SDVXDifficulty: OrderedDictionary<String, Int>] = [:]
        var gradeByDiff: [SDVXDifficulty: OrderedDictionary<String, Int>] = [:]
        var clearByLevel: [Int: OrderedDictionary<String, Int>] = [:]
        var plays = 0

        let clearKeys = SDVXClearType.sortedStringsWithoutNoPlay
        let gradeKeys = SDVXGrade.sortedStrings

        func emptyClearCounts() -> OrderedDictionary<String, Int> {
            OrderedDictionary(uniqueKeys: clearKeys, values: clearKeys.map { _ in 0 })
        }
        func emptyGradeCounts() -> OrderedDictionary<String, Int> {
            OrderedDictionary(uniqueKeys: gradeKeys, values: gradeKeys.map { _ in 0 })
        }

        for record in records {
            plays += record.playCount
            let difficulty = record.difficultyEnum
            // Group all infinite-tier charts under .infinite for the per-category view
            let category: SDVXDifficulty = difficulty.isInfiniteTier ? .infinite : difficulty

            if clearByDiff[category] == nil { clearByDiff[category] = emptyClearCounts() }
            if gradeByDiff[category] == nil { gradeByDiff[category] = emptyGradeCounts() }

            if clearKeys.contains(record.clearType) {
                clearByDiff[category]?[record.clearType]? += 1
            }
            if gradeKeys.contains(record.grade) {
                gradeByDiff[category]?[record.grade]? += 1
            }

            let levelInt = Int(Double(record.level) ?? 0.0)
            if levelInt > 0 {
                if clearByLevel[levelInt] == nil { clearByLevel[levelInt] = emptyClearCounts() }
                if clearKeys.contains(record.clearType) {
                    clearByLevel[levelInt]?[record.clearType]? += 1
                }
            }
        }

        let topForces = records.map { chartForce($0) }.sorted(by: >).prefix(50)
        let computedVolforce = (topForces.reduce(0.0, +) * 100).rounded() / 100

        withAnimation(.smooth.speed(2.0)) {
            self.clearTypePerDifficulty = clearByDiff
            self.gradePerDifficulty = gradeByDiff
            self.clearTypePerLevel = clearByLevel
            self.totalCharts = records.count
            self.totalPlays = plays
            self.volforce = computedVolforce
            self.dataState = .presenting
        }
    }
}

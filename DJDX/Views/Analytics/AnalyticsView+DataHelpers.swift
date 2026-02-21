//
//  AnalyticsView+DataHelpers.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/02.
//

import Foundation
import OrderedCollections

// MARK: - Data Fetching & Computation

extension AnalyticsView {

    func computeAllCounts(from songRecords: [IIDXSongRecord]) -> (
        clearType: [Int: OrderedDictionary<String, Int>],
        djLevel: [Int: OrderedDictionary<String, Int>]
    ) {
        let clearTypes = IIDXClearType.sortedStringsWithoutNoPlay
        let djLevels = IIDXDJLevel.sortedStrings.reversed()

        var clearTypeResult: [Int: OrderedDictionary<String, Int>] = [:]
        var djLevelResult: [Int: OrderedDictionary<String, Int>] = [:]

        for difficulty in difficulties {
            clearTypeResult[difficulty] = OrderedDictionary(
                uniqueKeys: clearTypes,
                values: clearTypes.map { _ in 0 }
            )
            djLevelResult[difficulty] = OrderedDictionary(
                uniqueKeys: djLevels,
                values: djLevels.map { _ in 0 }
            )
        }

        for songRecord in songRecords {
            let scores: [IIDXLevelScore] = [
                songRecord.beginnerScore,
                songRecord.normalScore,
                songRecord.hyperScore,
                songRecord.anotherScore,
                songRecord.leggendariaScore
            ]
            for score in scores {
                if score.difficulty == 0 { continue }

                if score.clearType != "NO PLAY" && score.score > 0 {
                    clearTypeResult[score.difficulty]?[score.clearType]? += 1
                }

                if let djLevel = IIDXDJLevel(rawValue: score.djLevel), djLevel != .none {
                    djLevelResult[score.difficulty]?[score.djLevel]? += 1
                }
            }
        }

        return (clearTypeResult, djLevelResult)
    }

    func convertToEnumKeyed(_ data: [Int: OrderedDictionary<String, Int>]) -> [Int: [IIDXDJLevel: Int]] {
        var result: [Int: [IIDXDJLevel: Int]] = [:]
        for (difficulty, counts) in data {
            var inner: [IIDXDJLevel: Int] = [:]
            for level in IIDXDJLevel.sorted {
                inner[level] = counts[level.rawValue] ?? 0
            }
            result[difficulty] = inner
        }
        return result
    }

    func sumOfCounts(_ data: [Int: OrderedDictionary<String, Int>]) -> Int {
        data.values.reduce(0) { sum, dict in
            sum + dict.values.reduce(0, +)
        }
    }

    func buildOrderedClearType(
        from raw: [Int: [String: Int]]
    ) -> [Int: OrderedDictionary<String, Int>] {
        let clearTypes = IIDXClearType.sortedStringsWithoutNoPlay
        var result: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            let counts = raw[difficulty] ?? [:]
            result[difficulty] = OrderedDictionary(
                uniqueKeys: clearTypes,
                values: clearTypes.map { counts[$0] ?? 0 }
            )
        }
        return result
    }

    func buildOrderedDJLevel(
        from raw: [Int: [String: Int]]
    ) -> [Int: OrderedDictionary<String, Int>] {
        let djLevels = Array(IIDXDJLevel.sortedStrings.reversed())
        var result: [Int: OrderedDictionary<String, Int>] = [:]
        for difficulty in difficulties {
            let counts = raw[difficulty] ?? [:]
            result[difficulty] = OrderedDictionary(
                uniqueKeys: djLevels,
                values: djLevels.map { counts[$0] ?? 0 }
            )
        }
        return result
    }
}

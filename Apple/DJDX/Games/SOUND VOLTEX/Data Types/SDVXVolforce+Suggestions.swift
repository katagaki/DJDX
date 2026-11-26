import Foundation

struct SDVXVolforceSuggestion: Identifiable {
    let id = UUID()
    let record: SDVXSongRecord
    let score: Int
    let currentGrade: String
    let targetGrade: String
    let targetScore: Int
    let volforceGain: Int

    var pointsNeeded: Int { targetScore - score }
}

extension SDVXVolforce {

    static let gradeThresholds: [(grade: SDVXGrade, score: Int)] = [
        (.c, 6_500_000), (.b, 7_500_000), (.a, 8_700_000), (.aPlus, 9_000_000),
        (.aa, 9_300_000), (.aaPlus, 9_500_000), (.aaa, 9_700_000), (.aaaPlus, 9_800_000),
        (.s, 9_900_000)
    ]

    static func gainText(_ gain: Int) -> String {
        String(format: "+%.3f", Double(gain) / 1000.0)
    }

    static func suggestions(allRecords: [SDVXSongRecord],
                            candidates: [SDVXSongRecord]) -> [SDVXVolforceSuggestion] {
        let pool = RatingPool(values: allRecords.map(chartForce), limit: chartLimit)
        return candidates.compactMap { record -> SDVXVolforceSuggestion? in
            let level = Double(record.level) ?? 0.0
            guard level > 0, record.highScore > 0,
                  let target = gradeThresholds.first(where: { $0.score > record.highScore }) else { return nil }
            let clearType = record.clearTypeEnum == .noPlay ? .played : record.clearTypeEnum
            let currentForce = force(level: level, score: record.highScore, clearType: record.clearTypeEnum)
            let targetForce = force(level: level, score: target.score, clearType: clearType)
            let gain = pool.gain(replacing: currentForce, with: targetForce)
            guard gain > 0 else { return nil }
            return SDVXVolforceSuggestion(
                record: record,
                score: record.highScore,
                currentGrade: SDVXGrade.grade(forScore: record.highScore).rawValue,
                targetGrade: target.grade.rawValue,
                targetScore: target.score,
                volforceGain: gain
            )
        }
        .sorted {
            if $0.volforceGain != $1.volforceGain { return $0.volforceGain > $1.volforceGain }
            return $0.pointsNeeded < $1.pointsNeeded
        }
    }
}

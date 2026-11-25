import Foundation

struct SDVXVolforceSuggestion: Identifiable {
    let id = UUID()
    let songTitle: String
    let level: String
    let difficulty: SDVXDifficulty
    let score: Int
    let currentGrade: String
    let targetGrade: String
    let targetScore: Int
    let volforceGain: Int

    var pointsNeeded: Int { targetScore - score }
}

enum SDVXVolforce {

    static let chartLimit = 50

    static let gradeThresholds: [(grade: SDVXGrade, score: Int)] = [
        (.c, 6_500_000), (.b, 7_500_000), (.a, 8_700_000), (.aPlus, 9_000_000),
        (.aa, 9_300_000), (.aaPlus, 9_500_000), (.aaa, 9_700_000), (.aaaPlus, 9_800_000),
        (.s, 9_900_000)
    ]

    static let gradeCoefficients: [SDVXGrade: Int] = [
        .s: 105, .aaaPlus: 102, .aaa: 100, .aaPlus: 97, .aa: 94,
        .aPlus: 91, .a: 88, .b: 85, .c: 82, .d: 80
    ]

    static func clearCoefficient(_ clearType: SDVXClearType) -> Int {
        switch clearType {
        case .perfectUltimateChain: return 110
        case .ultimateChain: return 106
        case .excessive: return 102
        case .complete: return 100
        case .played: return 50
        default: return 0
        }
    }

    static func force(level: Double, score: Int, clearType: SDVXClearType) -> Int {
        guard level > 0, score > 0 else { return 0 }
        let grade = SDVXGrade.grade(forScore: score)
        let value = level * Double(score) * Double(gradeCoefficients[grade] ?? 0) *
            Double(clearCoefficient(clearType)) * 20.0 / 10_000_000.0 / 10_000.0
        return Int((value + 1e-9).rounded(.down))
    }

    static func force(_ record: SDVXSongRecord) -> Int {
        force(level: Double(record.level) ?? 0.0, score: record.highScore, clearType: record.clearTypeEnum)
    }

    static func gainText(_ gain: Int) -> String {
        String(format: "+%.3f", Double(gain) / 1000.0)
    }

    static func total(_ records: [SDVXSongRecord]) -> Double {
        Double(RatingPool(values: records.map { force($0) }, limit: chartLimit).total) / 1000.0
    }

    static func suggestions(allRecords: [SDVXSongRecord],
                            candidates: [SDVXSongRecord]) -> [SDVXVolforceSuggestion] {
        let pool = RatingPool(values: allRecords.map { force($0) }, limit: chartLimit)
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
                songTitle: record.title,
                level: record.level,
                difficulty: record.difficultyEnum,
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

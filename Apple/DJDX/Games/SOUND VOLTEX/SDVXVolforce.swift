import Foundation

enum SDVXVolforce {

    static let chartLimit = 50

    static func total(_ records: [SDVXSongRecord]) -> Double {
        Double(RatingPool(values: records.map(chartForce), limit: chartLimit).total) / 1000.0
    }

    static func chartForce(_ record: SDVXSongRecord) -> Int {
        force(level: Double(record.level) ?? 0.0, score: record.highScore, clearType: record.clearTypeEnum)
    }

    static func force(level: Double, score: Int, clearType: SDVXClearType) -> Int {
        guard level > 0, score > 0 else { return 0 }
        let score = min(score, 10_000_000)
        let grade = gradeCoefficients[SDVXGrade.grade(forScore: score)] ?? 0
        let value = level * Double(score) * Double(grade) * Double(lampCoefficient(clearType)) *
            20.0 / 10_000_000.0 / 10_000.0
        return Int((value + 1e-9).rounded(.down))
    }

    static let gradeCoefficients: [SDVXGrade: Int] = [
        .s: 105, .aaaPlus: 102, .aaa: 100, .aaPlus: 97, .aa: 94,
        .aPlus: 91, .a: 88, .b: 85, .c: 82, .d: 80
    ]

    static func lampCoefficient(_ clearType: SDVXClearType) -> Int {
        switch clearType {
        case .perfectUltimateChain: return 110
        case .ultimateChain: return 105
        case .excessive: return 102
        case .complete: return 100
        case .played: return 50
        default: return 0
        }
    }
}

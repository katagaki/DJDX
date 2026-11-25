import Foundation

enum SDVXVolforce {

    static func total(_ records: [SDVXSongRecord]) -> Double {
        let top = records.map(chartForce).sorted(by: >).prefix(50)
        return Double(top.reduce(0, +)) / 1000.0
    }

    static func chartForce(_ record: SDVXSongRecord) -> Int {
        let level = Double(record.level) ?? 0.0
        guard level > 0, record.highScore > 0 else { return 0 }
        let rate = Double(min(record.highScore, 10_000_000)) / 10_000_000.0
        let grade = gradeCoefficient(SDVXGrade.grade(forScore: record.highScore))
        let lamp = lampCoefficient(record.clearTypeEnum)
        return Int((level * rate * grade * lamp * 20.0).rounded(.down))
    }

    static let gradeCoefficients: [SDVXGrade: Double] = [
        .s: 1.05, .aaaPlus: 1.02, .aaa: 1.0, .aaPlus: 0.97, .aa: 0.94,
        .aPlus: 0.91, .a: 0.88, .b: 0.85, .c: 0.82, .d: 0.8
    ]

    static func gradeCoefficient(_ grade: SDVXGrade) -> Double {
        gradeCoefficients[grade] ?? 0.0
    }

    static func lampCoefficient(_ clearType: SDVXClearType) -> Double {
        switch clearType {
        case .perfectUltimateChain: return 1.1
        case .ultimateChain: return 1.05
        case .excessive: return 1.02
        case .complete: return 1.0
        case .played: return 0.5
        default: return 0.0
        }
    }
}

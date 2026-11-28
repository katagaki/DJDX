import SwiftUI

enum PopnClass {

    struct Tier {
        let minimum: Double
        let name: String
        let color: Color
    }

    static let tiers: [Tier] = [
        Tier(minimum: 91, name: "神", color: Color(red: 0.82, green: 0.13, blue: 0.23)),
        Tier(minimum: 79, name: "仙人", color: Color(red: 0.75, green: 0.19, blue: 0.31)),
        Tier(minimum: 68, name: "将軍", color: Color(red: 0.75, green: 0.5, blue: 0.13)),
        Tier(minimum: 59, name: "アイドル", color: Color(red: 0.69, green: 0.63, blue: 0.06)),
        Tier(minimum: 46, name: "刑事", color: Color(red: 0.13, green: 0.56, blue: 0.25)),
        Tier(minimum: 34, name: "番長", color: Color(red: 0.1, green: 0.56, blue: 0.5)),
        Tier(minimum: 21, name: "小学生", color: Color(red: 0.18, green: 0.44, blue: 0.75)),
        Tier(minimum: 0, name: "にゃんこ", color: Color(red: 0.56, green: 0.47, blue: 0.38))
    ]

    static let chartCount = 50

    static func point(level: Int, score: Int, medal: PopnMedal) -> Double {
        guard level > 0, score >= 50000 else { return 0.0 }
        let raw = Double(10000 * level + score - 50000 + medal.popnClassBonus) / 5440.0
        return min(floor(raw * 100.0) / 100.0, 100.0)
    }

    static func topCharts(_ records: [PopnSongRecord]) -> [PopnSongRecord] {
        Array(records
            .filter { $0.popnClassPoint > 0 }
            .sorted { $0.popnClassPoint > $1.popnClassPoint }
            .prefix(chartCount))
    }

    static func value(for records: [PopnSongRecord]) -> Double {
        let top = topCharts(records)
        guard !top.isEmpty else { return 0.0 }
        let average = top.reduce(0.0) { $0 + $1.popnClassPoint } / Double(top.count)
        return floor(average * 100.0) / 100.0
    }

    static func tier(for value: Double) -> Tier {
        tiers.first { value >= $0.minimum } ?? tiers[tiers.count - 1]
    }
}

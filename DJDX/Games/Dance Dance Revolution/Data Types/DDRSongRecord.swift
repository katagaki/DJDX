import SwiftUI

final class DDRSongRecord: Equatable, Hashable, @unchecked Sendable {
    var songIndex: String = ""
    var title: String = ""
    var style: String = DDRPlayStyle.single.rawValue
    var difficulty: String = DDRDifficulty.beginner.rawValue
    var level: Int = 0
    var version: Int = 0
    var score: Int = 0
    var rank: String = ""
    var clearKind: String = ""
    var flareSkill: Int = 0
    var flareRank: String = ""
    var jacketPath: String = ""

    init() {}

    var styleEnum: DDRPlayStyle {
        DDRPlayStyle(rawValue: style) ?? .single
    }

    var difficultyEnum: DDRDifficulty {
        DDRDifficulty(rawValue: difficulty) ?? .unknown
    }

    var hasScore: Bool {
        score > 0 || !clearKind.isEmpty
    }

    var rankDisplay: String {
        Self.rankDisplay(forStem: rank)
    }

    static func rankDisplay(forStem stem: String) -> String {
        guard !stem.isEmpty else { return "" }
        let parts = stem.split(separator: "_")
        let letter = (parts.first.map(String.init) ?? stem).uppercased()
        guard parts.count > 1 else { return letter }
        switch parts[1] {
        case "p": return letter + "+"
        case "m": return letter + "-"
        default: return letter
        }
    }

    static let clearLampOrder: [String] = [
        "marv", "perf", "great", "good", "life4", "clear", "assist", "fail"
    ]

    static let rankOrder: [String] = [
        "aaa", "aa_p", "aa", "aa_m", "a_p", "a", "a_m",
        "b_p", "b", "b_m", "c_p", "c", "c_m", "d_p", "d", "e"
    ]

    var clearLampSortIndex: Int {
        Self.clearLampOrder.firstIndex(of: clearKind) ?? Self.clearLampOrder.count
    }

    static func orderedClearLamps(_ lamps: Set<String>) -> [String] {
        lamps.sorted { lhs, rhs in
            let lhsRank = clearLampOrder.firstIndex(of: lhs) ?? clearLampOrder.count
            let rhsRank = clearLampOrder.firstIndex(of: rhs) ?? clearLampOrder.count
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs < rhs
        }
    }

    static func orderedRanks(_ ranks: Set<String>) -> [String] {
        ranks.sorted { lhs, rhs in
            let lhsRank = rankOrder.firstIndex(of: lhs) ?? rankOrder.count
            let rhsRank = rankOrder.firstIndex(of: rhs) ?? rankOrder.count
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs < rhs
        }
    }

    static func clearColor(for clearKind: String) -> Color {
        switch clearKind {
        case "marv": Color(red: 0.45, green: 0.85, blue: 1.0)
        case "perf": Color(red: 1.0, green: 0.82, blue: 0.0)
        case "great": .green
        case "good": Color(red: 0.2, green: 0.55, blue: 1.0)
        case "life4": .red
        case "clear": Color(red: 0.0, green: 0.8, blue: 0.5)
        case "assist": .purple
        case "fail": .gray
        default: .secondary
        }
    }

    static func rankColor(forStem stem: String) -> Color {
        let letter = stem.split(separator: "_").first.map(String.init) ?? stem
        switch letter {
        case "aaa": return Color(red: 1.0, green: 0.82, blue: 0.0)
        case "aa": return .orange
        case "a": return Color(red: 1.0, green: 0.55, blue: 0.2)
        case "b": return .green
        case "c": return .blue
        case "d": return .purple
        default: return .gray
        }
    }

    var clearDisplay: String {
        clearKind.uppercased()
    }

    var levelText: String {
        level > 0 ? String(level) : "?"
    }

    func titleCompact() -> String {
        title.ddrCompact
    }

    static func == (lhs: DDRSongRecord, rhs: DDRSongRecord) -> Bool {
        lhs.songIndex == rhs.songIndex &&
        lhs.style == rhs.style &&
        lhs.difficulty == rhs.difficulty &&
        lhs.score == rhs.score &&
        lhs.clearKind == rhs.clearKind &&
        lhs.rank == rhs.rank
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(songIndex)
        hasher.combine(style)
        hasher.combine(difficulty)
    }
}

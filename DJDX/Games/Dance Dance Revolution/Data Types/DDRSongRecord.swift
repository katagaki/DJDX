import Foundation

// One DDRSongRecord is one chart (song + play style + difficulty), mirroring the
// SDVX per-chart model. Levels are not present in the scraped HTML and stay 0
// until backfilled from an external metadata source.
final class DDRSongRecord: Equatable, Hashable, @unchecked Sendable {
    var songIndex: String = ""
    var title: String = ""
    var style: String = DDRPlayStyle.single.rawValue
    var difficulty: String = DDRDifficulty.beginner.rawValue
    var level: Int = 0
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

    // Grade tokens look like "a", "aa", "aaa", "a_p" (A+), "a_m" (A-).
    var rankDisplay: String {
        guard !rank.isEmpty else { return "" }
        let parts = rank.split(separator: "_")
        let letter = (parts.first.map(String.init) ?? rank).uppercased()
        guard parts.count > 1 else { return letter }
        switch parts[1] {
        case "p": return letter + "+"
        case "m": return letter + "-"
        default: return letter
        }
    }

    var clearDisplay: String {
        clearKind.uppercased()
    }

    var levelText: String {
        level > 0 ? String(level) : "?"
    }

    func titleCompact() -> String {
        title.compact
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

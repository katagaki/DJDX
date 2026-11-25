import Foundation

final class PopnSongRecord: Equatable, Hashable, @unchecked Sendable {
    var title: String = ""
    var genre: String = ""
    var artist: String = ""
    var difficulty: String = PopnDifficulty.unknown.rawValue
    var level: Int = 0
    var score: Int = 0
    var medal: String = PopnMedal.noPlay.rawValue
    var rank: String = PopnRank.none.rawValue

    init() {}

    init(jsonRow: [String: Any]) {
        self.title = (jsonRow["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.genre = (jsonRow["genre"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.artist = (jsonRow["artist"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.difficulty = PopnDifficulty(label: jsonRow["difficulty"] as? String ?? "").rawValue
        self.level = Self.intValue(jsonRow["level"])
        self.score = Self.intValue(jsonRow["score"])
        self.medal = PopnMedal(code: jsonRow["medal"] as? String ?? "").rawValue
        self.rank = PopnRank(code: jsonRow["rank"] as? String ?? "").rawValue
    }

    private static func intValue(_ value: Any?) -> Int {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String {
            return Int(stringValue.filter { $0.isNumber }) ?? 0
        }
        return 0
    }

    var difficultyEnum: PopnDifficulty {
        PopnDifficulty(rawValue: difficulty) ?? .unknown
    }

    var medalEnum: PopnMedal {
        PopnMedal(rawValue: medal) ?? .noPlay
    }

    var clearType: PopnClearType {
        medalEnum.clearType
    }

    var rankEnum: PopnRank {
        PopnRank(rawValue: rank) ?? .none
    }

    var popnClassPoint: Double {
        PopnClass.point(level: level, score: score, medal: medalEnum)
    }

    func titleCompact() -> String {
        title.compact
    }

    static func == (lhs: PopnSongRecord, rhs: PopnSongRecord) -> Bool {
        lhs.titleCompact() == rhs.titleCompact() &&
        lhs.genre == rhs.genre &&
        lhs.difficulty == rhs.difficulty &&
        lhs.level == rhs.level &&
        lhs.score == rhs.score &&
        lhs.medal == rhs.medal &&
        lhs.rank == rhs.rank
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(titleCompact())
        hasher.combine(genre)
        hasher.combine(difficulty)
    }
}

import Foundation

final class GITADORASongRecord: Equatable, Hashable, @unchecked Sendable {
    var title: String = ""
    var instrument: String = GITADORAInstrument.guitar.rawValue
    var difficulty: String = GITADORADifficulty.unknown.rawValue
    var level: String = ""
    var achievementRate: String = ""
    var score: Int = 0
    var clearType: String = GITADORAClearType.noPlay.rawValue
    var rank: String = GITADORARank.none.rawValue

    init() {}

    init(jsonRow: [String: Any]) {
        self.title = (jsonRow["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.instrument = (GITADORAInstrument(rawValue: jsonRow["instrument"] as? String ?? "") ?? .guitar).rawValue
        self.difficulty = (GITADORADifficulty(rawValue: jsonRow["difficulty"] as? String ?? "") ?? .unknown).rawValue
        self.level = Self.decimalString(jsonRow["level"])
        self.achievementRate = Self.decimalString(jsonRow["rate"])
        self.score = Self.intValue(jsonRow["score"])

        let clear = jsonRow["clear"] as? String ?? ""
        self.clearType = (GITADORAClearType(rawValue: clear) ?? .unknown) == .unknown
            ? GITADORAClearType.noPlay.rawValue : clear

        let rankString = (jsonRow["rank"] as? String ?? "").uppercased()
        if let parsedRank = GITADORARank(rawValue: rankString), GITADORARank.sorted.contains(parsedRank) {
            self.rank = parsedRank.rawValue
        } else if let rate = Double(achievementRate) {
            self.rank = GITADORARank(achievementRate: rate).rawValue
        }
    }

    private static func decimalString(_ value: Any?) -> String {
        let number: Double?
        if let doubleValue = value as? Double {
            number = doubleValue
        } else if let intValue = value as? Int {
            number = Double(intValue)
        } else if let stringValue = value as? String {
            number = Double(stringValue.filter { $0.isNumber || $0 == "." })
        } else {
            number = nil
        }
        guard let number else { return "" }
        return String(format: "%.2f", number)
    }

    private static func intValue(_ value: Any?) -> Int {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String {
            return Int(stringValue.filter { $0.isNumber }) ?? 0
        }
        return 0
    }

    var instrumentEnum: GITADORAInstrument {
        GITADORAInstrument(rawValue: instrument) ?? .guitar
    }

    var difficultyEnum: GITADORADifficulty {
        GITADORADifficulty(rawValue: difficulty) ?? .unknown
    }

    var clearTypeEnum: GITADORAClearType {
        GITADORAClearType(rawValue: clearType) ?? .unknown
    }

    var rankEnum: GITADORARank {
        GITADORARank(rawValue: rank) ?? .unknown
    }

    var levelValue: Double {
        Double(level) ?? 0.0
    }

    var levelBucket: String {
        guard levelValue > 0 else { return "" }
        return String(Int(levelValue))
    }

    var achievementRateValue: Double {
        Double(achievementRate) ?? 0.0
    }

    var skillValue: Double {
        (levelValue * achievementRateValue * 20.0).rounded(.down) / 100.0
    }

    func titleCompact() -> String {
        title.compact
    }

    static func == (lhs: GITADORASongRecord, rhs: GITADORASongRecord) -> Bool {
        lhs.titleCompact() == rhs.titleCompact() &&
        lhs.instrument == rhs.instrument &&
        lhs.difficulty == rhs.difficulty &&
        lhs.level == rhs.level &&
        lhs.achievementRate == rhs.achievementRate &&
        lhs.score == rhs.score &&
        lhs.clearType == rhs.clearType &&
        lhs.rank == rhs.rank
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(titleCompact())
        hasher.combine(instrument)
        hasher.combine(difficulty)
    }
}

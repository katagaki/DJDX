import Foundation
import SwiftData

// Polaris Chord has no CSV export; each record is built from a chart in the
// json/pdata_getdata.html API response. Stored via SQLite, like SDVXSongRecord.
@Model
final class PolarisChordSongRecord: Equatable, Hashable, @unchecked Sendable {
    var title: String = ""
    var musicID: String = ""
    var category: String = ""
    var difficulty: String = PolarisChordDifficulty.unknown.rawValue
    var level: String = ""
    var achievementRate: String = ""
    var score: Int = 0
    var clearType: String = PolarisChordClearType.noPlay.rawValue
    var grade: String = PolarisChordGrade.none.rawValue

    init() {
        // Empty default initializer required by SwiftData
    }

    init(jsonRow: [String: Any]) {
        self.title = jsonRow["title"] as? String ?? ""
        self.musicID = jsonRow["musicID"] as? String ?? ""
        self.category = jsonRow["category"] as? String ?? ""
        self.level = jsonRow["level"] as? String ?? ""
        self.score = Self.intValue(jsonRow["score"])

        // achievement_rate arrives as an integer hundredths (9784 -> "97.84").
        let rate = Self.intValue(jsonRow["rate"])
        self.achievementRate = String(format: "%.2f", Double(rate) / 100.0)

        let difficultyType = Self.intValue(jsonRow["difficulty"])
        self.difficulty = PolarisChordDifficulty(chartDifficultyType: difficultyType).rawValue

        let clearStatus = Self.intValue(jsonRow["clearStatus"])
        self.clearType = PolarisChordClearType(statusCode: clearStatus).rawValue

        self.grade = PolarisChordGrade(achievementRate: rate).rawValue
    }

    // API values may arrive as numbers or numeric strings.
    private static func intValue(_ value: Any?) -> Int {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String {
            return Int(stringValue.filter { $0.isNumber }) ?? 0
        }
        return 0
    }

    var difficultyEnum: PolarisChordDifficulty {
        PolarisChordDifficulty(rawValue: difficulty) ?? .unknown
    }

    var clearTypeEnum: PolarisChordClearType {
        PolarisChordClearType(rawValue: clearType) ?? .unknown
    }

    var gradeEnum: PolarisChordGrade {
        PolarisChordGrade(rawValue: grade) ?? .unknown
    }

    var achievementRateValue: Double {
        Double(achievementRate) ?? 0.0
    }

    func titleCompact() -> String {
        title.compact
    }

    static func == (lhs: PolarisChordSongRecord, rhs: PolarisChordSongRecord) -> Bool {
        lhs.titleCompact() == rhs.titleCompact() &&
        lhs.difficulty == rhs.difficulty &&
        lhs.level == rhs.level &&
        lhs.achievementRate == rhs.achievementRate &&
        lhs.clearType == rhs.clearType &&
        lhs.grade == rhs.grade
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(titleCompact())
        hasher.combine(difficulty)
    }
}

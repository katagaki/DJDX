import Foundation
import SwiftData

// The SDVX CSV is one row per chart (song + difficulty), unlike the IIDX CSV
// which is one row per song. Each SDVXSongRecord therefore carries a single
// chart's score.
@Model
final class SDVXSongRecord: Equatable, Hashable, @unchecked Sendable {
    var title: String = ""
    var difficulty: String = SDVXDifficulty.novice.rawValue
    var level: String = ""
    var clearType: String = SDVXClearType.noPlay.rawValue
    var grade: String = SDVXGrade.none.rawValue
    var highScore: Int = 0
    var exScore: Int = 0
    var playCount: Int = 0
    var clearCount: Int = 0
    var ultimateChainCount: Int = 0
    var perfectCount: Int = 0

    init() {
        // Empty default initializer required by SwiftData
    }

    // Based on the SDVX e-amusement CSV format.
    init(csvRowData: [String: Any]) {
        self.title = csvRowData["楽曲名"] as? String ?? ""
        self.difficulty = csvRowData["難易度"] as? String ?? ""
        self.level = csvRowData["楽曲レベル"] as? String ?? ""
        self.clearType = csvRowData["クリアランク"] as? String ?? SDVXClearType.noPlay.rawValue
        self.grade = csvRowData["スコアグレード"] as? String ?? SDVXGrade.none.rawValue
        self.highScore = Int(csvRowData["ハイスコア"] as? String ?? "0") ?? 0
        self.exScore = Int(csvRowData["EXスコア"] as? String ?? "0") ?? 0
        self.playCount = Int(csvRowData["プレー回数"] as? String ?? "0") ?? 0
        self.clearCount = Int(csvRowData["クリア回数"] as? String ?? "0") ?? 0
        self.ultimateChainCount = Int(csvRowData["ULTIMATE CHAIN"] as? String ?? "0") ?? 0
        self.perfectCount = Int(csvRowData["PERFECT"] as? String ?? "0") ?? 0
    }

    var difficultyEnum: SDVXDifficulty {
        SDVXDifficulty(rawValue: difficulty) ?? .unknown
    }

    var clearTypeEnum: SDVXClearType {
        SDVXClearType(rawValue: clearType) ?? .unknown
    }

    var gradeEnum: SDVXGrade {
        SDVXGrade(rawValue: grade) ?? .unknown
    }

    func titleCompact() -> String {
        title.compact
    }

    static func == (lhs: SDVXSongRecord, rhs: SDVXSongRecord) -> Bool {
        lhs.titleCompact() == rhs.titleCompact() &&
        lhs.difficulty == rhs.difficulty &&
        lhs.level == rhs.level &&
        lhs.highScore == rhs.highScore &&
        lhs.clearType == rhs.clearType &&
        lhs.grade == rhs.grade
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(titleCompact())
        hasher.combine(difficulty)
    }
}

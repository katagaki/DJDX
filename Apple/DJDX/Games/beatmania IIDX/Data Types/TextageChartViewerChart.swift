import Foundation

struct TextageChartViewerChart: Sendable, Hashable {

    var songId: String
    var version: Int
    var title: String

    var spBeginner: Int
    var spNormal: Int
    var spHyper: Int
    var spAnother: Int
    var spLeggendaria: Int
    var dpBeginner: Int
    var dpNormal: Int
    var dpHyper: Int
    var dpAnother: Int
    var dpLeggendaria: Int

    func level(for difficulty: IIDXLevel, playType: IIDXPlayType) -> Int {
        switch (playType, difficulty) {
        case (.single, .beginner): return spBeginner
        case (.single, .normal): return spNormal
        case (.single, .hyper): return spHyper
        case (.single, .another): return spAnother
        case (.single, .leggendaria): return spLeggendaria
        case (.double, .beginner): return dpBeginner
        case (.double, .normal): return dpNormal
        case (.double, .hyper): return dpHyper
        case (.double, .another): return dpAnother
        case (.double, .leggendaria): return dpLeggendaria
        default: return 0
        }
    }

    func hasChart(for difficulty: IIDXLevel, playType: IIDXPlayType) -> Bool {
        level(for: difficulty, playType: playType) > 0
    }

    func pageURL(for difficulty: IIDXLevel, playType: IIDXPlayType) -> URL? {
        guard hasChart(for: difficulty, playType: playType),
              let difficultyCode = Self.difficultyCode(for: difficulty) else { return nil }
        let playTypeCode: String
        switch playType {
        case .single: playTypeCode = "sp"
        case .double: playTypeCode = "dp"
        }
        let folder = version == 35 ? "s" : String(version)
        let path = "chart/\(folder)/\(songId)/\(difficultyCode)/\(playTypeCode)"
        return URL(string: "https://textage-chart-viewer.vercel.app/\(path)")
    }

    func textageScoreURL(for difficulty: IIDXLevel, playType: IIDXPlayType) -> URL? {
        let levelValue = level(for: difficulty, playType: playType)
        guard levelValue > 0, levelValue < TextageChart.base36.count,
              let difficultyChar = TextageChart.difficultyChar(for: difficulty) else { return nil }
        let folder = version == 35 ? "s" : String(version)
        let sideChar = playType == .double ? "D" : "1"
        let query = "\(sideChar)\(difficultyChar)\(TextageChart.base36[levelValue])00"
        return URL(string: "https://textage.cc/score/\(folder)/\(songId).html?\(query)")
    }

    private static func difficultyCode(for difficulty: IIDXLevel) -> String? {
        switch difficulty {
        case .beginner: return "b"
        case .normal: return "n"
        case .hyper: return "h"
        case .another: return "a"
        case .leggendaria: return "l"
        default: return nil
        }
    }
}

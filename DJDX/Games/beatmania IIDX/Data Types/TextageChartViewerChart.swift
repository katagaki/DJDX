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
        let path = "chart/\(version)/\(songId)/\(difficultyCode)/\(playTypeCode)"
        return URL(string: "https://textage-chart-viewer.vercel.app/\(path)")
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

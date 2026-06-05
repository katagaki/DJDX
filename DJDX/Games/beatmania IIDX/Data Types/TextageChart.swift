import Foundation

struct TextageChart: Sendable, Hashable {

    var tag: String
    var version: Int
    var title: String

    var spNormal: Int
    var spHyper: Int
    var spAnother: Int
    var spLeggendaria: Int
    var dpNormal: Int
    var dpHyper: Int
    var dpAnother: Int
    var dpLeggendaria: Int

    private static let base36 = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    func level(for difficulty: IIDXLevel, playType: IIDXPlayType) -> Int {
        switch (playType, difficulty) {
        case (.single, .normal): return spNormal
        case (.single, .hyper): return spHyper
        case (.single, .another): return spAnother
        case (.single, .leggendaria): return spLeggendaria
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

    func pageURL(for difficulty: IIDXLevel,
                 playType: IIDXPlayType,
                 playSide: IIDXPlaySide) -> URL? {
        let levelValue = level(for: difficulty, playType: playType)
        guard levelValue > 0, levelValue < Self.base36.count,
              let difficultyChar = Self.difficultyChar(for: difficulty) else { return nil }

        let folder = version == 35 ? "s" : String(version)
        let sideChar: String
        switch playType {
        case .double: sideChar = "D"
        case .single: sideChar = playSide == .side2P ? "2" : "1"
        }
        let levelChar = String(Self.base36[levelValue])
        let query = "\(sideChar)\(difficultyChar)\(levelChar)00"
        return URL(string: "https://textage.cc/score/\(folder)/\(tag).html?\(query)")
    }

    private static func difficultyChar(for difficulty: IIDXLevel) -> String? {
        switch difficulty {
        case .normal: return "N"
        case .hyper: return "H"
        case .another: return "A"
        case .leggendaria: return "X"
        default: return nil
        }
    }
}

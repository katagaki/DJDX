import Foundation

struct ChartNote: Equatable, Sendable {
    var game: Game
    var title: String
    var chart: String
    var text: String = ""
    var greenNumber: Int?
    var laneCover: Int?
    var judgmentOffset: Int?

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && greenNumber == nil && laneCover == nil && judgmentOffset == nil
    }

    static func iidxChart(playType: IIDXPlayType, level: IIDXLevel) -> String {
        let prefix = level == .beginner ? "SP" : playType.displayName()
        let name: String
        switch level {
        case .beginner: name = "BEGINNER"
        case .normal: name = "NORMAL"
        case .hyper: name = "HYPER"
        case .another: name = "ANOTHER"
        case .leggendaria: name = "LEGGENDARIA"
        default: name = ""
        }
        return "\(prefix)-\(name)"
    }
}

struct ChartNoteTarget: Identifiable, Hashable {
    var game: Game
    var title: String
    var chart: String
    var chartLabel: String

    var id: String { "\(game.rawValue)|\(title)|\(chart)" }
}

extension GITADORASongRecord {
    var chartNoteTarget: ChartNoteTarget {
        ChartNoteTarget(game: .gitadora, title: title,
                        chart: "\(instrument)-\(difficulty)",
                        chartLabel: "\(instrument) \(difficulty) \(level)")
    }
}

extension DDRSongRecord {
    var chartNoteTarget: ChartNoteTarget {
        ChartNoteTarget(game: .danceDanceRevolution, title: title,
                        chart: "\(style)-\(difficulty)",
                        chartLabel: "\(style) \(difficulty) \(level)")
    }
}

extension PolarisChordSongRecord {
    var chartNoteTarget: ChartNoteTarget {
        ChartNoteTarget(game: .polarisChord, title: title,
                        chart: difficulty,
                        chartLabel: "\(difficulty) \(level)")
    }
}

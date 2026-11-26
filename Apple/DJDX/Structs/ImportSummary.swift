import SwiftUI

enum ImportSummaryGame: Hashable {
    case iidx
    case sdvx
    case polarisChord
    case ddr

    var gradeTitle: String {
        switch self {
        case .iidx: return "DJ LEVEL"
        case .ddr: return "RANK"
        case .sdvx, .polarisChord: return "GRADE"
        }
    }
}

struct ImportSummary {
    let game: ImportSummaryGame
    let importDate: Date
    let previousImportDate: Date?
    let ratings: [ImportSummaryRating]
    let personalBests: [ImportSummaryEntry]
    var notesRadars: [ImportSummaryNotesRadar] = []
}

struct ImportSummaryNotesRadar: Identifiable {
    let playType: String
    let radar: RadarData
    let previousRadar: RadarData?

    var id: String { playType }
}

struct ImportSummaryRating: Identifiable, Hashable {
    let name: String
    let previousValue: Double?
    let value: Double
    let fractionDigits: Int

    var id: String { name }

    var delta: Double? {
        previousValue.map { value - $0 }
    }
}

enum ImportSummaryValueStyle: Hashable {
    case iidxClearType
    case iidxDJLevel
    case sdvxGrade
    case polarisChordGrade
    case color(Color)
}

struct ImportSummaryChange: Hashable {
    let current: String
    let style: ImportSummaryValueStyle
}

struct ImportSummaryEntry: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let difficulty: String
    let level: String
    let difficultyColor: Color
    let lampStyle: AnyShapeStyle
    let levelValue: Double
    let previousScore: Int?
    let score: Int?
    let lamp: ImportSummaryChange?
    let grade: ImportSummaryChange?

    static func == (lhs: ImportSummaryEntry, rhs: ImportSummaryEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ImportSummaryTarget: Identifiable, Hashable {
    let id: String
}

enum ImportSummaryRank {
    static func isImprovement(from previous: String?, to latest: String, bestFirst order: [String]) -> Bool {
        guard let latestIndex = order.firstIndex(of: latest) else { return false }
        let previousIndex = previous.flatMap { order.firstIndex(of: $0) } ?? order.count
        return latestIndex < previousIndex
    }
}

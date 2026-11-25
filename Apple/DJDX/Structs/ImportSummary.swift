import SwiftUI

struct ImportSummary {
    let importDate: Date
    let previousImportDate: Date?
    let ratings: [ImportSummaryRating]
    let personalBests: [ImportSummaryEntry]
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

struct ImportSummaryChange: Hashable {
    let previous: String?
    let current: String
    let color: Color
}

struct ImportSummaryEntry: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let chart: String
    let chartColor: Color
    let levelValue: Double
    let previousScore: Int?
    let score: Int?
    let lamp: ImportSummaryChange?
    let grade: ImportSummaryChange?
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

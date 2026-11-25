import Foundation

struct TrendPoint: Identifiable, Hashable, Sendable {
    let date: Date
    let value: Double

    var id: Date { date }
}

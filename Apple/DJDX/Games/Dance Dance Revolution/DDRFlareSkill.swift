import Foundation

enum DDRFlareSkill {

    static let chartLimit = 30

    static func total(_ records: [DDRSongRecord]) -> Int {
        Dictionary(grouping: records, by: { category(for: $0.version) })
            .values
            .reduce(0) { total, records in
                total + RatingPool(values: records.map(\.flareSkill), limit: chartLimit).total
            }
    }

    static func category(for version: Int) -> Int {
        switch version {
        case 1...13: return 1
        case 14...16: return 2
        case 17...: return 3
        default: return 0
        }
    }
}

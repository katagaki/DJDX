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
        case 1...11: return 1
        case 12...19: return 2
        default: return 3
        }
    }
}

import Foundation

enum DDRFlareSkill {

    static func total(_ records: [DDRSongRecord]) -> Int {
        Dictionary(grouping: records.filter { $0.flareSkill > 0 }, by: { category(for: $0.version) })
            .values
            .reduce(0) { total, records in
                total + records.map(\.flareSkill).sorted(by: >).prefix(30).reduce(0, +)
            }
    }

    static func category(for version: Int) -> Int {
        switch version {
        case 1...11: return 1
        case 12...16: return 2
        case 17...: return 3
        default: return 0
        }
    }
}

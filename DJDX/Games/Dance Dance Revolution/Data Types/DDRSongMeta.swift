import Foundation

// Chart metadata for one song (levels per chart + debut version), sourced from
// BEMANIWiki and joined to scraped records by compact title. A level of 0 means
// the chart does not exist.
final class DDRSongMeta: Equatable, Hashable, @unchecked Sendable {
    var title: String = ""
    var version: Int = 0
    var spBeginner: Int = 0
    var spBasic: Int = 0
    var spDifficult: Int = 0
    var spExpert: Int = 0
    var spChallenge: Int = 0
    var dpBasic: Int = 0
    var dpDifficult: Int = 0
    var dpExpert: Int = 0
    var dpChallenge: Int = 0

    init() {}

    // levelStrings is the 9-cell BEMANIWiki tail: SP(Be,Ba,Di,Ex,Ch) + DP(Ba,Di,Ex,Ch).
    init(title: String, version: Int, levelStrings: [String]) {
        self.title = title
        self.version = version
        func value(_ index: Int) -> Int {
            guard index < levelStrings.count else { return 0 }
            return Int(levelStrings[index].filter(\.isNumber)) ?? 0
        }
        spBeginner = value(0)
        spBasic = value(1)
        spDifficult = value(2)
        spExpert = value(3)
        spChallenge = value(4)
        dpBasic = value(5)
        dpDifficult = value(6)
        dpExpert = value(7)
        dpChallenge = value(8)
    }

    func titleCompact() -> String {
        title.compact
    }

    func level(style: DDRPlayStyle, difficulty: DDRDifficulty) -> Int {
        switch (style, difficulty) {
        case (.single, .beginner): spBeginner
        case (.single, .basic): spBasic
        case (.single, .difficult): spDifficult
        case (.single, .expert): spExpert
        case (.single, .challenge): spChallenge
        case (.double, .basic): dpBasic
        case (.double, .difficult): dpDifficult
        case (.double, .expert): dpExpert
        case (.double, .challenge): dpChallenge
        default: 0
        }
    }

    static func == (lhs: DDRSongMeta, rhs: DDRSongMeta) -> Bool {
        lhs.titleCompact() == rhs.titleCompact()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(titleCompact())
    }
}

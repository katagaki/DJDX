import Foundation

final class IIDXSong: Equatable, @unchecked Sendable {
    var title: String = ""
    var spNoteCount: IIDXNoteCount?
    var dpNoteCount: IIDXNoteCount?
    var time: String = ""
    var movie: String = ""
    var layer: String = ""
    var spLevels: [IIDXLevel: Int] = [:]
    var dpLevels: [IIDXLevel: Int] = [:]

    init() {}

    init(_ tableColumnData: [String]) {
        self.title = tableColumnData[0]
        let spBeginnerNoteCount = tableColumnData[1]
        let spNormalNoteCount = tableColumnData[2]
        let spHyperNoteCount = tableColumnData[3]
        let spAnotherNoteCount = tableColumnData[4]
        let spLeggendariaNoteCount = tableColumnData[5]
        let dpNormalNoteCount = tableColumnData[6]
        let dpHyperNoteCount = tableColumnData[7]
        let dpAnotherNoteCount = tableColumnData[8]
        let dpLeggendariaNoteCount = tableColumnData[9]
        if !(spBeginnerNoteCount == "-" &&
            spNormalNoteCount == "-" &&
            spHyperNoteCount == "-" &&
            spAnotherNoteCount == "-" &&
            spLeggendariaNoteCount == "-") {
            self.spNoteCount = IIDXNoteCount(
                beginnerNoteCount: spBeginnerNoteCount,
                normalNoteCount: spNormalNoteCount,
                hyperNoteCount: spHyperNoteCount,
                anotherNoteCount: spAnotherNoteCount,
                leggendariaNoteCount: spLeggendariaNoteCount,
                playType: .single
            )
        }
        if !(dpNormalNoteCount == "-" &&
             dpHyperNoteCount == "-" &&
             dpAnotherNoteCount == "-" &&
             dpLeggendariaNoteCount == "-" ) {
            self.dpNoteCount = IIDXNoteCount(
                beginnerNoteCount: "-",
                normalNoteCount: dpNormalNoteCount,
                hyperNoteCount: dpHyperNoteCount,
                anotherNoteCount: dpAnotherNoteCount,
                leggendariaNoteCount: dpLeggendariaNoteCount,
                playType: .double
            )
        }
        self.time = tableColumnData[10]
        self.movie = tableColumnData[11]
        self.layer = tableColumnData[12]
    }

    func titleCompact() -> String {
        return title.compact
    }

    // The BEMANIWiki new-song list carries a level table whose row is
    // [SP B/N/H/A/L, DP N/H/A/L, BPM, GENRE, TITLE, ARTIST]; chart-type prefixes
    // like [CN]/[BSS] wrap the numeric level and are stripped here.
    static func parseLevelRow(_ columnData: [String]) -> (compactTitle: String, levels: IIDXSongLevels)? {
        guard columnData.count == 13 else { return nil }
        let title = columnData[11]
        guard !title.isEmpty else { return nil }
        func level(_ raw: String) -> Int? {
            let stripped = raw.replacingOccurrences(
                of: "\\[[^\\]]*\\]", with: "", options: .regularExpression
            )
            guard let value = Int(stripped.trimmingCharacters(in: .whitespaces)),
                  (1...12).contains(value) else { return nil }
            return value
        }
        var single: [IIDXLevel: Int] = [:]
        let singlePairs: [(IIDXLevel, String)] = [
            (.beginner, columnData[0]), (.normal, columnData[1]), (.hyper, columnData[2]),
            (.another, columnData[3]), (.leggendaria, columnData[4])
        ]
        for (chartLevel, raw) in singlePairs {
            if let value = level(raw) { single[chartLevel] = value }
        }
        var double: [IIDXLevel: Int] = [:]
        let doublePairs: [(IIDXLevel, String)] = [
            (.normal, columnData[5]), (.hyper, columnData[6]),
            (.another, columnData[7]), (.leggendaria, columnData[8])
        ]
        for (chartLevel, raw) in doublePairs {
            if let value = level(raw) { double[chartLevel] = value }
        }
        return (title.compact, IIDXSongLevels(single: single, double: double))
    }

    static func == (lhs: IIDXSong, rhs: IIDXSong) -> Bool {
        return lhs.title == rhs.title
    }

    static func == (lhs: IIDXSong, rhs: IIDXSongRecord) -> Bool {
        return lhs.title == rhs.title
    }
}

struct IIDXSongLevels: Sendable {
    var single: [IIDXLevel: Int]
    var double: [IIDXLevel: Int]
}

struct IIDXNoteCount: Codable, Equatable {
    var beginnerNoteCount: Int?
    var normalNoteCount: Int?
    var hyperNoteCount: Int?
    var anotherNoteCount: Int?
    var leggendariaNoteCount: Int?
    var playType: IIDXPlayType

    init(beginnerNoteCount: String,
         normalNoteCount: String,
         hyperNoteCount: String,
         anotherNoteCount: String,
         leggendariaNoteCount: String,
         playType: IIDXPlayType) {
        self.beginnerNoteCount = Int(beginnerNoteCount)
        self.normalNoteCount = Int(normalNoteCount)
        self.hyperNoteCount = Int(hyperNoteCount)
        self.anotherNoteCount = Int(anotherNoteCount)
        self.leggendariaNoteCount = Int(leggendariaNoteCount)
        self.playType = playType
    }

    func noteCount(for level: IIDXLevel) -> Int? {
        switch level {
        case .beginner: return beginnerNoteCount
        case .normal: return normalNoteCount
        case .hyper: return hyperNoteCount
        case .another: return anotherNoteCount
        case .leggendaria: return leggendariaNoteCount
        default: return nil
        }
    }
}

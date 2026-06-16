import CoreGraphics
import Foundation

struct OCRLine: Sendable {
    let text: String
    let box: CGRect
}

struct IIDXSongCandidate: Sendable {
    let id: Int64
    let title: String
    let compact: String
    let playType: IIDXPlayType
    let difficulties: [IIDXLevel: Int]

    func matchesChart(level: IIDXLevel, difficulty: Int, playType: IIDXPlayType) -> Bool {
        self.playType == playType && difficulties[level] == difficulty
    }
}

struct IIDXResultParse: Sendable {
    var songTitle: String?
    var matchedSongID: Int64?
    var level: IIDXLevel = .unknown
    var difficulty: Int = 0
    var playType: IIDXPlayType = .single
    var exScore: Int = 0
    var perfectGreat: Int = 0
    var great: Int = 0
    var miss: Int = 0
    var clearType: String = IIDXClearType.noPlay.rawValue
    var djLevel: String = IIDXDJLevel.none.rawValue
    var confidence: Double = 0.0
}

// The IIDX result screen shows two value columns per metric: best score (left)
// and this-play score (right). The current play is always the rightmost value
// of the expected type on a metric's row, which also skips NEW RECORD badges.
enum IIDXResultParser {

    private static let grades = ["AAA", "AA", "A", "B", "C", "D", "E", "F"]

    // Free-text title lookup ignores UI chrome words; matching against the song
    // DB is position-independent, with a largest-font fallback so the captured
    // title survives an unrecognized song, an odd angle, or a different crop.
    private static let titleStopwords: Set<String> = [
        "RESULT", "STAGE", "JUDGE", "FAST", "SLOW", "COMBO", "BREAK", "NOTES",
        "PLAYER", "PASELI", "NEWRECORD", "RECORD", "BEST", "SCORE", "TYPE",
        "DJLEVEL", "LEVEL", "MISSCOUNT", "MISS", "COUNT", "GREAT", "GOOD", "BAD",
        "POOR", "AMUSEMENT", "EAMUSEMENT", "BEGINNER", "NORMAL", "HYPER",
        "ANOTHER", "LEGGENDARIA", "NOPLAY", "PERFECT", "PGREAT", "FEAT", "SP", "DP",
        "テンキー", "アプリ", "画像", "保存", "スコア", "ベスト", "今回", "プレー"
    ]

    static func parse(lines: [OCRLine],
                      titleLines: [OCRLine],
                      songs: [IIDXSongCandidate]) -> IIDXResultParse {
        var parse = IIDXResultParse()
        var hits = 0

        parse.playType = detectPlayType(lines: lines)
        if let (level, difficulty) = detectChart(lines: lines) {
            parse.level = level
            parse.difficulty = difficulty
        }

        let resolved = resolveTitle(lines: titleLines, songs: songs,
                                    level: parse.level,
                                    difficulty: parse.difficulty,
                                    playType: parse.playType)
        if let matched = resolved.matched {
            parse.songTitle = matched.title
            parse.matchedSongID = matched.id
            if parse.level != .unknown, let known = matched.difficulties[parse.level] {
                parse.difficulty = known
            }
            hits += 1
        } else if let rawTitle = resolved.rawTitle {
            parse.songTitle = rawTitle
        }

        if let label = findLabel(lines, keywords: ["CLEARTYPE", "TYPE"]),
           let value = rightmostValue(on: label, in: lines, map: clearTypeOf) {
            parse.clearType = value
            hits += 1
        } else {
            let global = detectClearTypeGlobal(lines)
            if global != IIDXClearType.noPlay.rawValue {
                parse.clearType = global
                hits += 1
            }
        }

        if let label = findLabel(lines, keywords: ["DJLEVEL", "DJ"]),
           let value = rightmostValue(on: label, in: lines, map: gradeOf) {
            parse.djLevel = value
            hits += 1
        }

        if let label = findLabel(lines, keywords: ["EXSCORE", "SCORE"]),
           let value = rightmostValue(on: label, in: lines, map: scoreOf) {
            parse.exScore = value
            hits += 1
        }

        if let label = findLabel(lines, keywords: ["MISSCOUNT", "MISS"]),
           let value = rightmostValue(on: label, in: lines, map: scoreOf) {
            parse.miss = value
            hits += 1
        }

        let (perfectGreat, great) = detectGreats(lines: lines)
        if let perfectGreat {
            parse.perfectGreat = perfectGreat
            hits += 1
        }
        if let great {
            parse.great = great
            hits += 1
        }

        var bonus = 0.0
        if parse.exScore > 0,
           parse.perfectGreat > 0 || parse.great > 0,
           parse.exScore == 2 * parse.perfectGreat + parse.great {
            bonus = 1.0
        }
        parse.confidence = min(1.0, (Double(hits) + bonus) / 7.0)
        return parse
    }

    // MARK: - Title

    // Narrow the song pool by the parsed chart (play type + level + difficulty)
    // first, then fuzzy-match the OCR title within that small set. Filtering makes
    // edit-distance matching safe enough to absorb OCR errors; an unfiltered pool
    // stays strict to avoid false matches, and anything unmatched keeps the raw text.
    private static func resolveTitle(lines: [OCRLine],
                                     songs: [IIDXSongCandidate],
                                     level: IIDXLevel,
                                     difficulty: Int,
                                     playType: IIDXPlayType)
    -> (matched: IIDXSongCandidate?, rawTitle: String?) {
        guard !songs.isEmpty else {
            return (nil, rawTitleCandidate(lines))
        }

        let (pool, threshold) = candidatePool(
            songs: songs, level: level, difficulty: difficulty, playType: playType
        )

        let needles = titleNeedles(lines)

        for needle in needles {
            if let exact = pool.first(where: { $0.compact == needle }) {
                return (exact, nil)
            }
        }

        var best: (song: IIDXSongCandidate, ratio: Double)?
        for needle in needles where needle.count >= 3 {
            for song in pool where song.compact.count >= 2 {
                let ratio = editRatio(needle, song.compact)
                if ratio <= threshold, best == nil || ratio < best!.ratio {
                    best = (song, ratio)
                }
            }
        }
        if let best {
            return (best.song, nil)
        }
        return (nil, rawTitleCandidate(lines))
    }

    // The difficulty number is easily misread (10 -> IO), and it gates the pool,
    // so tolerate an off-by-one before falling back to the whole level category.
    private static func candidatePool(
        songs: [IIDXSongCandidate],
        level: IIDXLevel,
        difficulty: Int,
        playType: IIDXPlayType
    ) -> (pool: [IIDXSongCandidate], threshold: Double) {
        guard level != .unknown else { return (songs, 0.15) }
        if difficulty > 0 {
            let near = songs.filter { candidate in
                candidate.playType == playType
                && (candidate.difficulties[level].map { abs($0 - difficulty) <= 1 } ?? false)
            }
            if !near.isEmpty { return (near, 0.40) }
        }
        let category = songs.filter { $0.playType == playType && $0.difficulties[level] != nil }
        if !category.isEmpty { return (category, 0.15) }
        return (songs, 0.15)
    }

    private static func titleNeedles(_ lines: [OCRLine]) -> [String] {
        var seen = Set<String>()
        var needles: [String] = []
        for line in lines where isFreeText(line.text) {
            let needle = line.text.compact
            if needle.count >= 2, seen.insert(needle).inserted {
                needles.append(needle)
            }
        }
        return needles
    }

    private static func editRatio(_ lhs: String, _ rhs: String) -> Double {
        let distance = levenshtein(Array(lhs), Array(rhs))
        let longest = max(lhs.count, rhs.count)
        return longest == 0 ? 0.0 : Double(distance) / Double(longest)
    }

    private static func levenshtein(_ lhs: [Character], _ rhs: [Character]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }
        var previous = Array(0...rhs.count)
        var current = [Int](repeating: 0, count: rhs.count + 1)
        for row in 1...lhs.count {
            current[0] = row
            for col in 1...rhs.count {
                let cost = lhs[row - 1] == rhs[col - 1] ? 0 : 1
                current[col] = min(previous[col] + 1, current[col - 1] + 1, previous[col - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[rhs.count]
    }

    private static func rawTitleCandidate(_ lines: [OCRLine]) -> String? {
        let candidates = lines.filter { isFreeText($0.text) }
        let best = candidates.max { lhs, rhs in
            if abs(lhs.box.height - rhs.box.height) > 0.005 {
                return lhs.box.height < rhs.box.height
            }
            return lhs.text.count < rhs.text.count
        }
        return best?.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isFreeText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        let letters = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard letters.count >= 2 else { return false }
        guard intOf(trimmed) == nil, gradeOf(trimmed) == nil, clearTypeOf(trimmed) == nil else {
            return false
        }
        let normalized = normalize(trimmed)
        return !titleStopwords.contains { normalized.contains($0) }
    }

    // MARK: - Chart / play type

    private static func detectPlayType(lines: [OCRLine]) -> IIDXPlayType {
        let joined = lines.map { $0.text.uppercased() }.joined(separator: " ")
        if joined.contains("DOUBLE") || joined.range(of: #"\bDP\b"#, options: .regularExpression) != nil {
            return .double
        }
        return .single
    }

    private static func detectChart(lines: [OCRLine]) -> (IIDXLevel, Int)? {
        let labels: [(String, IIDXLevel)] = [
            ("LEGGENDARIA", .leggendaria),
            ("ANOTHER", .another),
            ("HYPER", .hyper),
            ("NORMAL", .normal),
            ("BEGINNER", .beginner)
        ]
        var classLine: OCRLine?
        var foundLevel: IIDXLevel = .unknown
        for line in lines {
            let upper = line.text.uppercased()
            for (keyword, level) in labels where upper.contains(keyword) {
                foundLevel = level
                classLine = line
                break
            }
            if foundLevel != .unknown { break }
        }
        guard foundLevel != .unknown, let classLine else { return nil }

        var difficulty = 0
        for token in tokens(classLine.text) where difficulty == 0 {
            if let value = difficultyToken(token) { difficulty = value }
        }
        if difficulty == 0 {
            var best: (value: Int, deltaX: CGFloat)?
            for line in lines where onRow(line, label: classLine) && line.box.midX > classLine.box.minX {
                for token in tokens(line.text) {
                    guard let value = difficultyToken(token) else { continue }
                    let deltaX = line.box.midX - classLine.box.maxX
                    if best == nil || deltaX < best!.deltaX {
                        best = (value, deltaX)
                    }
                }
            }
            difficulty = best?.value ?? 0
        }
        return (foundLevel, difficulty)
    }

    // MARK: - Judges

    private static func detectGreats(lines: [OCRLine]) -> (Int?, Int?) {
        var rows: [(midY: CGFloat, value: Int)] = []
        for line in lines where normalize(line.text).contains("GREAT") {
            let inline = integers(in: line.text).last
            if let value = inline ?? rightmostValue(on: line, in: lines, map: scoreOf) {
                rows.append((line.box.midY, value))
            }
        }
        rows.sort { $0.midY > $1.midY }
        let perfectGreat = rows.indices.contains(0) ? rows[0].value : nil
        let great = rows.indices.contains(1) ? rows[1].value : nil
        return (perfectGreat, great)
    }

    // MARK: - Row-scoped value lookup

    private static func findLabel(_ lines: [OCRLine], keywords: [String]) -> OCRLine? {
        let matches = lines.filter { line in
            let label = normalize(line.text)
            return keywords.contains { label.contains($0) }
        }
        if let exact = matches.first(where: { line in
            keywords.contains(normalize(line.text))
        }) {
            return exact
        }
        return matches.first
    }

    private static func rightmostValue<T>(on label: OCRLine,
                                          in lines: [OCRLine],
                                          map: (String) -> T?) -> T? {
        let maxDeltaX = max(label.box.height * 18.0, 0.42)
        var best: (midX: CGFloat, value: T)?
        for line in lines where line.text != label.text {
            guard onRow(line, label: label) else { continue }
            guard line.box.midX > label.box.maxX else { continue }
            guard line.box.midX - label.box.midX < maxDeltaX else { continue }
            guard let value = map(line.text) else { continue }
            if best == nil || line.box.midX > best!.midX {
                best = (line.box.midX, value)
            }
        }
        return best?.value
    }

    private static func onRow(_ line: OCRLine, label: OCRLine) -> Bool {
        line.box.maxY > label.box.minY && line.box.minY < label.box.maxY
    }

    // MARK: - Value maps

    private static func clearTypeOf(_ text: String) -> String? {
        let label = normalize(text)
        let ordered: [(String, IIDXClearType)] = [
            ("FULLCOMBO", .fullComboClear),
            ("EXHARD", .exHardClear),
            ("HARDCLEAR", .hardClear),
            ("EASYCLEAR", .easyClear),
            ("ASSIST", .assistClear),
            ("FAILED", .failed),
            ("CLEAR", .clear)
        ]
        for (keyword, type) in ordered where label.contains(keyword) {
            return type.rawValue
        }
        return nil
    }

    private static func gradeOf(_ text: String) -> String? {
        let components = text.uppercased().split(whereSeparator: { $0 == " " || $0 == "\t" })
        for grade in grades where components.contains(where: { $0 == Substring(grade) }) {
            return grade
        }
        return nil
    }

    private static func intOf(_ text: String) -> Int? {
        let cleaned = text.uppercased().filter { $0 != " " && $0 != "," && $0 != "+" }
        guard !cleaned.isEmpty else { return nil }
        let mapped = String(cleaned.map(confusedDigit))
        guard mapped.allSatisfy({ $0.isNumber }), let value = Int(mapped) else { return nil }
        return value
    }

    // A metric row carries best (old, left) and this-play (new, right) values.
    // When OCR merges both columns into one line ("999 9999"), split on whitespace
    // and keep the rightmost number so the new value still wins.
    private static func scoreOf(_ text: String) -> Int? {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .compactMap { intOf(String($0)) }
            .last
    }

    private static func confusedDigit(_ character: Character) -> Character {
        switch character {
        case "I", "L", "|": return "1"
        case "O", "Q": return "0"
        case "S": return "5"
        case "B": return "8"
        case "Z": return "2"
        case "G": return "9"
        default: return character
        }
    }

    private static func detectClearTypeGlobal(_ lines: [OCRLine]) -> String {
        let joined = lines.map { normalize($0.text) }.joined(separator: " ")
        let ordered: [(String, IIDXClearType)] = [
            ("FULLCOMBO", .fullComboClear),
            ("EXHARD", .exHardClear),
            ("HARDCLEAR", .hardClear),
            ("EASYCLEAR", .easyClear),
            ("ASSIST", .assistClear),
            ("FAILED", .failed),
            ("CLEAR", .clear)
        ]
        for (keyword, type) in ordered where joined.contains(keyword) {
            return type.rawValue
        }
        return IIDXClearType.noPlay.rawValue
    }

    // MARK: - Text helpers

    private static func integers(in text: String) -> [Int] {
        text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    }

    // Recover a 1-12 difficulty from a token, mapping common OCR letter/digit
    // confusions (I/L -> 1, O/Q -> 0, S -> 5, B -> 8, ...). Rejects tokens that
    // still contain non-digits after mapping, so "SP"/"NOTES" never become numbers.
    private static func difficultyToken(_ text: String) -> Int? {
        let cleaned = text.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !cleaned.isEmpty, cleaned.count <= 3 else { return nil }
        let mapped = String(cleaned.map(confusedDigit))
        guard mapped.allSatisfy({ $0.isNumber }), let value = Int(mapped) else { return nil }
        return (1...12).contains(value) ? value : nil
    }

    private static func normalize(_ text: String) -> String {
        text.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
    }
}

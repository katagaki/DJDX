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
    let noteCounts: [IIDXLevel: Int]

    init(id: Int64, title: String, compact: String, playType: IIDXPlayType,
         difficulties: [IIDXLevel: Int], noteCounts: [IIDXLevel: Int] = [:]) {
        self.id = id
        self.title = title
        self.compact = compact
        self.playType = playType
        self.difficulties = difficulties
        self.noteCounts = noteCounts
    }

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
    var good: Int = 0
    var bad: Int = 0
    var poor: Int = 0
    var miss: Int = 0
    var clearType: String = IIDXClearType.noPlay.rawValue
    var djLevel: String = IIDXDJLevel.none.rawValue
    var confidence: Double = 0.0
}

// The IIDXResultDetector model localizes each result-screen field as its own
// region; this parser maps the OCR'd text of those regions onto a typed result.
// Fields use the "_now" (this-play) variants; "_prev"/"_delta" regions are ignored.
enum IIDXResultParser {

    private static let grades = ["AAA", "AA", "A", "B", "C", "D", "E", "F"]

    static func parse(regions: [DetectedRegion],
                      songs: [IIDXSongCandidate]) -> IIDXResultParse {
        var byLabel: [String: String] = [:]
        for region in regions {
            byLabel[region.label] = region.text
        }
        func text(_ label: String) -> String? {
            guard let value = byLabel[label]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }

        var parse = IIDXResultParse()
        var hits = 0

        parse.playType = detectPlayType(byLabel["difficulty_label"], byLabel["stage_label"])
        var ocrDifficulty = 0
        if let (level, difficulty) = detectChart(text("difficulty_label")) {
            parse.level = level
            ocrDifficulty = difficulty
            parse.difficulty = plausibleDifficulty(
                difficulty, level: level, playType: parse.playType, songs: songs
            ) ? difficulty : 0
        }

        let resolved = resolveTitle(titleText: text("song_title"), songs: songs,
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

        // ANOTHER/LEGGENDARIA charts are effectively never level 1; OCR frequently
        // drops the leading digit of "11". Correct it, but only when neither the
        // wiki nor imported data already knows this chart's level.
        if ocrDifficulty == 1,
           parse.level == .another || parse.level == .leggendaria,
           resolved.matched?.difficulties[parse.level] == nil {
            parse.difficulty = 11
        }

        if parse.level != .unknown { hits += 1 }

        if let value = text("clear_type_now").flatMap(clearTypeOf) {
            parse.clearType = value
            hits += 1
        }

        // The matched chart's note count is authoritative; the on-screen notes_count
        // OCR is only a fallback. A reliable note count makes the score-rate DJ-level
        // derivation trustworthy and bounds the judge reconciliation correctly.
        let notes = resolved.matched?.noteCounts[parse.level] ?? headlineNumber(text("notes_count"))
        if let value = headlineNumber(text("score_now")) {
            parse.exScore = sanitizedScore(value)
            hits += 1
        }
        if let value = headlineNumber(text("miss_count_now")) {
            parse.miss = value
            hits += 1
        }
        let pgRead = headlineNumber(text("judge_pgreat"))
        let greatRead = headlineNumber(text("judge_great"))
        var perfectGreat = pgRead
        var great = greatRead
        reconcileJudges(exScore: parse.exScore, notes: notes, perfectGreat: &perfectGreat, great: &great)
        if let perfectGreat { parse.perfectGreat = perfectGreat; hits += 1 }
        if let great { parse.great = great; hits += 1 }
        if let value = headlineNumber(text("judge_good")) { parse.good = value }
        if let value = headlineNumber(text("judge_bad")) { parse.bad = value }
        if let value = headlineNumber(text("judge_poor")) { parse.poor = value }

        // The dedicated rank classifier reads the on-screen DJ-level graphic
        // directly, so trust it first; fall back to the score-rate derivation only
        // when the classifier abstains. A >1-grade disagreement flags low confidence.
        let classified = text("dj_level_now").flatMap(gradeOf)
        let derived = derivedGrade(exScore: parse.exScore, notes: notes, parse: parse)
        let djResolution = resolveDJLevel(classified: classified, derived: derived)
        if let grade = djResolution.grade {
            parse.djLevel = grade
            hits += 1
        }
        let djLevelConflict = djResolution.conflict

        var bonus = 0.0
        if parse.exScore > 0, pgRead != nil, greatRead != nil,
           parse.exScore == 2 * parse.perfectGreat + parse.great {
            bonus = 1.0
        }
        parse.confidence = min(1.0, (Double(hits) + bonus) / 8.0)
        if djLevelConflict { parse.confidence = min(parse.confidence, 0.5) }
        return parse
    }

    // MARK: - Numbers

    // A 5-digit EX score is impossible (max is notes·2, well under 10000); the LED
    // font commonly appends a spurious trailing "1", so 13991 -> 1399.
    private static func sanitizedScore(_ value: Int) -> Int {
        guard (10000...99999).contains(value), value % 10 == 1 else { return value }
        return value / 10
    }

    // EX score = 2·perfect-great + great. The small judge fonts misread far more
    // often than the headline score, so recover a missing count from the others.
    private static func reconcileJudges(exScore: Int, notes: Int?,
                                        perfectGreat: inout Int?, great: inout Int?) {
        guard exScore > 0 else { return }
        if let perfect = perfectGreat, great == nil {
            let derived = exScore - 2 * perfect
            if derived >= 0, isWithinNotes(perfect + derived, notes: notes) { great = derived }
        } else if let good = great, perfectGreat == nil {
            let remainder = exScore - good
            if remainder >= 0, remainder % 2 == 0 {
                let perfect = remainder / 2
                if isWithinNotes(perfect + good, notes: notes) { perfectGreat = perfect }
            }
        }
    }

    private static func isWithinNotes(_ total: Int, notes: Int?) -> Bool {
        guard let notes else { return true }
        return total <= notes
    }

    private static func notesArePlausible(notes: Int, parse: IIDXResultParse) -> Bool {
        guard notes > 0 else { return false }
        let judged = parse.perfectGreat + parse.great + parse.good + parse.bad + parse.poor
        return notes >= judged
    }

    private static func gradeDistance(_ lhs: String, _ rhs: String) -> Int {
        guard let left = IIDXDJLevel(rawValue: lhs).flatMap({ IIDXDJLevel.sorted.firstIndex(of: $0) }),
              let right = IIDXDJLevel(rawValue: rhs).flatMap({ IIDXDJLevel.sorted.firstIndex(of: $0) }) else {
            return 0
        }
        return abs(left - right)
    }

    private static func derivedGrade(exScore: Int, notes: Int?, parse: IIDXResultParse) -> String? {
        guard let notes, notesArePlausible(notes: notes, parse: parse) else { return nil }
        return derivedDJLevel(exScore: exScore, notes: notes)
    }

    private static func resolveDJLevel(classified: String?, derived: String?)
    -> (grade: String?, conflict: Bool) {
        guard let classified else { return (derived, false) }
        let conflict = derived.map { gradeDistance(classified, $0) > 1 } ?? false
        return (classified, conflict)
    }

    private static func derivedDJLevel(exScore: Int, notes: Int?) -> String? {
        guard exScore > 0, let notes, notes > 0 else { return nil }
        let maxScore = notes * 2
        guard exScore <= maxScore else { return nil }
        let rate = Double(exScore) / Double(maxScore)
        switch rate {
        case (8.0 / 9.0)...: return IIDXDJLevel.djAAA.rawValue
        case (7.0 / 9.0)...: return IIDXDJLevel.djAA.rawValue
        case (6.0 / 9.0)...: return IIDXDJLevel.djA.rawValue
        case (5.0 / 9.0)...: return IIDXDJLevel.djB.rawValue
        case (4.0 / 9.0)...: return IIDXDJLevel.djC.rawValue
        case (3.0 / 9.0)...: return IIDXDJLevel.djD.rawValue
        case (2.0 / 9.0)...: return IIDXDJLevel.djE.rawValue
        default: return IIDXDJLevel.djF.rawValue
        }
    }

    // Headline value of a region: the first line (tallest, see detector ordering)
    // that yields digits, read leniently through the OCR letter/digit confusions.
    private static func headlineNumber(_ text: String?) -> Int? {
        guard let text else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            if let value = digits(String(line)) { return value }
        }
        return nil
    }

    // Drop spaces (the LED font kerns digits apart), map OCR letter/digit
    // confusions, then take the longest digit run — this keeps "1 045" → 1045
    // while discarding trailing words like the "NOTES" in "1174 NOTES".
    private static func digits(_ text: String) -> Int? {
        let mapped = text.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .map(confusedDigit)
        var best = "", current = ""
        for character in mapped {
            if character.isNumber {
                current.append(character)
            } else {
                if current.count > best.count { best = current }
                current = ""
            }
        }
        if current.count > best.count { best = current }
        return best.isEmpty ? nil : Int(best)
    }

    // MARK: - Title

    // Narrow the song pool by the parsed chart (play type + level + difficulty)
    // first, then fuzzy-match the OCR title within that small set. Filtering makes
    // edit-distance matching safe enough to absorb OCR errors; an unfiltered pool
    // stays strict to avoid false matches, and anything unmatched keeps the raw text.
    private static func resolveTitle(titleText: String?,
                                     songs: [IIDXSongCandidate],
                                     level: IIDXLevel,
                                     difficulty: Int,
                                     playType: IIDXPlayType)
    -> (matched: IIDXSongCandidate?, rawTitle: String?) {
        guard let titleText else { return (nil, nil) }
        let rawTitle = rawTitleCandidate(titleText)
        guard !songs.isEmpty else { return (nil, rawTitle) }

        let (pool, threshold) = candidatePool(
            songs: songs, level: level, difficulty: difficulty, playType: playType
        )
        let needles = titleNeedles(titleText)

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
        return (nil, rawTitle)
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

    private static func titleNeedles(_ text: String) -> [String] {
        var seen = Set<String>()
        var needles: [String] = []
        let lines = text.split(whereSeparator: \.isNewline).map(String.init) + [text]
        for line in lines {
            let needle = line.compact
            if needle.count >= 2, seen.insert(needle).inserted {
                needles.append(needle)
            }
        }
        return needles
    }

    private static func rawTitleCandidate(_ text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.max { $0.count < $1.count } ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
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

    // MARK: - Chart / play type

    private static func detectPlayType(_ texts: String?...) -> IIDXPlayType {
        let joined = texts.compactMap { $0 }.joined(separator: " ").uppercased()
        if joined.contains("DOUBLE") || joined.range(of: #"\bDP\b"#, options: .regularExpression) != nil {
            return .double
        }
        return .single
    }

    // A dropped digit reads "11" as "1", which then mis-gates the candidate pool
    // and blocks the DB difficulty correction. Reject a difficulty below the
    // lowest that actually exists for this level + play type in the song DB; the
    // title match then recovers the real value. Unknown DB (no songs) stays lenient.
    private static func plausibleDifficulty(
        _ difficulty: Int,
        level: IIDXLevel,
        playType: IIDXPlayType,
        songs: [IIDXSongCandidate]
    ) -> Bool {
        guard difficulty > 0 else { return false }
        let existing = songs.lazy
            .filter { $0.playType == playType }
            .compactMap { $0.difficulties[level] }
        guard let minimum = existing.min() else { return true }
        return difficulty >= minimum
    }

    private static func detectChart(_ text: String?) -> (IIDXLevel, Int)? {
        guard let text else { return nil }
        let labels: [(String, IIDXLevel)] = [
            ("LEGGENDARIA", .leggendaria),
            ("ANOTHER", .another),
            ("HYPER", .hyper),
            ("NORMAL", .normal),
            ("BEGINNER", .beginner)
        ]
        let upper = text.uppercased()
        var foundLevel: IIDXLevel = .unknown
        for (keyword, level) in labels where upper.contains(keyword) {
            foundLevel = level
            break
        }
        guard foundLevel != .unknown else { return nil }

        var difficulty = 0
        for token in tokens(text) where difficulty == 0 {
            if let value = difficultyToken(token) { difficulty = value }
        }
        return (foundLevel, difficulty)
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
        let components = text.uppercased().split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
        for grade in grades where components.contains(where: { $0 == Substring(grade) }) {
            return grade
        }
        return nil
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

    // MARK: - Text helpers

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).map(String.init)
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
            .replacingOccurrences(of: "\n", with: "")
    }
}

extension IIDXResultParser {

    // Re-analysis self-heal: EX score, the perfect-great/great split, and the miss
    // count are arithmetically linked (EX = 2·PGREAT + GREAT, MISS = BAD + POOR),
    // so recover whichever value the OCR dropped from the ones it did read.
    static func heal(_ parse: IIDXResultParse) -> IIDXResultParse {
        var healed = parse
        let perfectGreat = healed.perfectGreat
        let great = healed.great
        if healed.exScore == 0, perfectGreat + great > 0 {
            healed.exScore = 2 * perfectGreat + great
        } else if healed.exScore > 0, great == 0, perfectGreat > 0,
                  healed.exScore - 2 * perfectGreat >= 0 {
            healed.great = healed.exScore - 2 * perfectGreat
        } else if healed.exScore > 0, perfectGreat == 0, great > 0,
                  healed.exScore - great >= 0, (healed.exScore - great) % 2 == 0 {
            healed.perfectGreat = (healed.exScore - great) / 2
        }
        if healed.miss == 0, healed.bad + healed.poor > 0 {
            healed.miss = healed.bad + healed.poor
        }
        return healed
    }
}

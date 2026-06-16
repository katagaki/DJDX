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

enum IIDXResultParser {

    static func parse(lines: [OCRLine], songs: [IIDXSongCandidate]) -> IIDXResultParse {
        var parse = IIDXResultParse()
        var hits = 0
        let fieldCount = 7.0

        if let (title, id) = matchTitle(lines: lines, songs: songs) {
            parse.songTitle = title
            parse.matchedSongID = id
            hits += 1
        }

        parse.playType = detectPlayType(lines: lines)

        if let (level, difficulty) = detectChart(lines: lines) {
            parse.level = level
            parse.difficulty = difficulty
        }

        let clearType = detectClearType(lines: lines)
        if clearType != IIDXClearType.noPlay.rawValue {
            parse.clearType = clearType
            hits += 1
        }

        let djLevel = detectDJLevel(lines: lines)
        if djLevel != IIDXDJLevel.none.rawValue {
            parse.djLevel = djLevel
            hits += 1
        }

        if let exScore = number(near: ["EXSCORE", "SCORE"], lines: lines) {
            parse.exScore = exScore
            hits += 1
        }
        if let pgreat = number(near: ["PGREAT", "P-GREAT", "PERFECTGREAT"], lines: lines) {
            parse.perfectGreat = pgreat
            hits += 1
        }
        if let great = number(near: ["GREAT"], lines: lines, excluding: ["PGREAT", "P-GREAT", "PERFECTGREAT"]) {
            parse.great = great
            hits += 1
        }
        if let miss = number(near: ["MISS", "MISSCOUNT", "POOR"], lines: lines) {
            parse.miss = miss
            hits += 1
        }

        parse.confidence = min(1.0, Double(hits) / fieldCount)
        return parse
    }

    // MARK: - Title

    private static func matchTitle(lines: [OCRLine],
                                   songs: [IIDXSongCandidate]) -> (String, Int64)? {
        guard !songs.isEmpty else { return nil }
        let candidates = lines
            .filter { $0.text.compact.count >= 2 }
            .sorted { $0.box.maxY > $1.box.maxY }

        for line in candidates {
            let needle = line.text.compact
            if let exact = songs.first(where: { $0.compact == needle }) {
                return (exact.title, exact.id)
            }
        }

        var best: (song: IIDXSongCandidate, distance: Int)?
        for line in candidates.prefix(6) {
            let needle = line.text.compact
            guard needle.count >= 3 else { continue }
            for song in songs {
                if song.compact.contains(needle) || needle.contains(song.compact) {
                    let distance = abs(song.compact.count - needle.count)
                    if best == nil || distance < best!.distance {
                        best = (song, distance)
                    }
                }
            }
        }
        if let best, best.distance <= 4 {
            return (best.song.title, best.song.id)
        }
        return nil
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
        var foundLevel: IIDXLevel = .unknown
        for line in lines {
            let upper = line.text.uppercased()
            for (keyword, level) in labels where upper.contains(keyword) {
                foundLevel = level
                break
            }
            if foundLevel != .unknown { break }
        }
        guard foundLevel != .unknown else { return nil }

        var difficulty = 0
        for line in lines {
            let upper = line.text.uppercased()
            if upper.contains("LEVEL") || upper.contains("☆") {
                if let value = firstInteger(in: line.text), (1...12).contains(value) {
                    difficulty = value
                    break
                }
            }
        }
        return (foundLevel, difficulty)
    }

    // MARK: - Clear type

    private static func detectClearType(lines: [OCRLine]) -> String {
        let joined = lines.map { normalizeLabel($0.text) }.joined(separator: " ")
        let ordered: [(String, IIDXClearType)] = [
            ("FULLCOMBO", .fullComboClear),
            ("FULLCOMBOCLEAR", .fullComboClear),
            ("EXHARD", .exHardClear),
            ("HARDCLEAR", .hardClear),
            ("EASYCLEAR", .easyClear),
            ("ASSISTCLEAR", .assistClear),
            ("ASSISTEASY", .assistClear),
            ("FAILED", .failed),
            ("CLEAR", .clear)
        ]
        for (keyword, type) in ordered where joined.contains(keyword) {
            return type.rawValue
        }
        return IIDXClearType.noPlay.rawValue
    }

    // MARK: - DJ level

    private static func detectDJLevel(lines: [OCRLine]) -> String {
        let grades = ["AAA", "AA", "A", "B", "C", "D", "E", "F"]
        var labelled: OCRLine?
        for line in lines where normalizeLabel(line.text).contains("DJLEVEL") {
            labelled = line
            break
        }
        if let labelled, let grade = grades.first(where: {
            normalizeLabel(labelled.text).replacingOccurrences(of: "DJLEVEL", with: "") == $0
        }) {
            return grade
        }
        for grade in grades {
            if lines.contains(where: { normalizeLabel($0.text) == grade }) {
                return grade
            }
        }
        return IIDXDJLevel.none.rawValue
    }

    // MARK: - Numeric helpers

    private static func number(near labels: [String],
                               lines: [OCRLine],
                               excluding: [String] = []) -> Int? {
        let normalizedLabels = labels.map { normalizeLabel($0) }
        let normalizedExclusions = excluding.map { normalizeLabel($0) }

        for line in lines {
            let label = normalizeLabel(line.text)
            guard normalizedExclusions.allSatisfy({ !label.contains($0) }) else { continue }
            guard normalizedLabels.contains(where: { label.contains($0) }) else { continue }
            if let inline = firstInteger(in: line.text) {
                return inline
            }
            if let neighbor = nearestNumericLine(to: line, in: lines) {
                return neighbor
            }
        }
        return nil
    }

    private static func nearestNumericLine(to line: OCRLine, in lines: [OCRLine]) -> Int? {
        let center = CGPoint(x: line.box.midX, y: line.box.midY)
        var best: (value: Int, distance: CGFloat)?
        for candidate in lines where candidate.text != line.text {
            let trimmed = candidate.text.trimmingCharacters(in: .whitespaces)
            guard isNumeric(trimmed), let value = Int(digits(in: trimmed)) else { continue }
            let candidateCenter = CGPoint(x: candidate.box.midX, y: candidate.box.midY)
            let distance = hypot(candidateCenter.x - center.x, candidateCenter.y - center.y)
            if best == nil || distance < best!.distance {
                best = (value, distance)
            }
        }
        return best?.value
    }

    private static func firstInteger(in text: String) -> Int? {
        let scalars = digits(in: text)
        return scalars.isEmpty ? nil : Int(scalars)
    }

    private static func digits(in text: String) -> String {
        String(text.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) })
    }

    private static func isNumeric(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isNumber || $0 == "," || $0 == " " }
    }

    private static func normalizeLabel(_ text: String) -> String {
        text.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
    }
}

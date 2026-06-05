import Foundation

// Parses Textage's JavaScript data tables into chart entries.
//
// Both tables are plain JS object literals, one `'tag':[...]` entry per line,
// encoded in CP932 (Windows-31J). They are NOT JSON: bare hex constants A–F
// stand for 10–15, lines may be commented out with `//`, and `/* ... */`
// comments can appear inline.
//
// - titletbl.js maps `tag` to `[version, id, availability, "genre", "artist", "title", ...]`
// - actbl.js maps `tag` to 23 values: `[ttnum, then (level, option) pairs]` for
//   chart types in the order: SBo SB SN SH SA SX DB DN DH DA DX. The level of a
//   chart sits at the odd index of its pair (SN=5, SH=7, SA=9, SX=11,
//   DN=15, DH=17, DA=19, DX=21).
enum TextageTableParser {

    static func charts(titleTableText: String, accessTableText: String) -> [TextageChart] {
        let titles = parseTitleTable(titleTableText)
        let access = parseAccessTable(accessTableText)

        var charts: [TextageChart] = []
        for (tag, values) in access {
            guard let meta = titles[tag], values.count >= 23 else { continue }
            let chart = TextageChart(
                tag: tag,
                version: meta.version,
                title: meta.title,
                spNormal: values[5],
                spHyper: values[7],
                spAnother: values[9],
                spLeggendaria: values[11],
                dpNormal: values[15],
                dpHyper: values[17],
                dpAnother: values[19],
                dpLeggendaria: values[21]
            )
            // Keep only songs with at least one playable normal/hyper/another/leggendaria chart.
            let hasAnyChart = [
                chart.spNormal, chart.spHyper, chart.spAnother, chart.spLeggendaria,
                chart.dpNormal, chart.dpHyper, chart.dpAnother, chart.dpLeggendaria
            ].contains { $0 > 0 }
            if hasAnyChart, !chart.title.isEmpty {
                charts.append(chart)
            }
        }
        return charts
    }

    // MARK: - titletbl.js

    static func parseTitleTable(_ text: String) -> [String: (version: Int, title: String)] {
        var result: [String: (version: Int, title: String)] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = stripBlockComments(String(rawLine))
            guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//"),
                  let tag = extractTag(line),
                  let bracket = extractBracketContent(line),
                  let version = parseVersion(bracket) else { continue }
            let strings = quotedStrings(in: bracket)
            // Order within the array: genre, artist, title, (subtitle).
            guard strings.count >= 3 else { continue }
            let title = cleanTitle(strings[2])
            guard !title.isEmpty else { continue }
            result[tag] = (version, title)
        }
        return result
    }

    // MARK: - actbl.js

    static func parseAccessTable(_ text: String) -> [String: [Int]] {
        var result: [String: [Int]] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = stripBlockComments(String(rawLine))
            guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//"),
                  let tag = extractTag(line),
                  let bracket = extractBracketContent(line) else { continue }
            var values: [Int] = []
            for token in bracket.split(separator: ",", omittingEmptySubsequences: false) {
                values.append(parseLevelToken(token))
                if values.count >= 23 { break }
            }
            if values.count >= 23 { result[tag] = values }
        }
        return result
    }

    // MARK: - Token helpers

    private static func parseVersion(_ bracket: String) -> Int? {
        let first = bracket
            .split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if first == "SS" { return 35 }
        return Int(first)
    }

    private static func parseLevelToken(_ token: Substring) -> Int {
        let value = token.trimmingCharacters(in: .whitespaces)
        if let number = Int(value) { return number }
        if value.count == 1, let hex = Int(value, radix: 16) { return hex } // A–F → 10–15
        return 0 // "" or any non-numeric placeholder
    }

    private static func extractTag(_ line: String) -> String? {
        guard let firstQuote = line.firstIndex(of: "'") else { return nil }
        let afterFirst = line.index(after: firstQuote)
        guard let secondQuote = line[afterFirst...].firstIndex(of: "'") else { return nil }
        let tag = line[afterFirst..<secondQuote]
        guard !tag.isEmpty, tag.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return nil }
        return String(tag)
    }

    private static func extractBracketContent(_ line: String) -> String? {
        guard let open = line.firstIndex(of: "["),
              let close = line.lastIndex(of: "]"),
              open < close else { return nil }
        return String(line[line.index(after: open)..<close])
    }

    private static func stripBlockComments(_ line: String) -> String {
        line.replacingOccurrences(of: "/\\*.*?\\*/", with: "", options: .regularExpression)
    }

    private static func cleanTitle(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extracts the contents of each top-level double-quoted string, honouring `\"` escapes.
    private static func quotedStrings(in string: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuote = false
        var escaped = false
        for character in string {
            if inQuote {
                if escaped {
                    current.append(character)
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    result.append(current)
                    current = ""
                    inQuote = false
                } else {
                    current.append(character)
                }
            } else if character == "\"" {
                inQuote = true
                current = ""
            }
        }
        return result
    }
}

extension Data {

    // Textage's data tables are encoded in CP932 (Windows-31J), a superset of
    // Shift-JIS. Foundation's `.shiftJIS` rejects bytes that CP932 accepts, so
    // decode via the DOS Japanese (CP932) encoding instead.
    func decodedAsTextageTable() -> String? {
        let cp932 = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosJapanese.rawValue)
        )
        return String(data: self, encoding: String.Encoding(rawValue: cp932))
    }
}

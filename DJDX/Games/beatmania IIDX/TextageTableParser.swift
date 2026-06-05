import Foundation
import SwiftSoup

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
        if value.count == 1, let hex = Int(value, radix: 16) { return hex }
        return 0
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
        let stripped = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let unescaped = (try? SwiftSoup.Entities.unescape(stripped)) ?? stripped
        return unescaped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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

    func decodedAsTextageTable() -> String? {
        let cp932 = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosJapanese.rawValue)
        )
        return String(data: self, encoding: String.Encoding(rawValue: cp932))
    }
}

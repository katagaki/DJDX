import Foundation
import SQLite

struct IIDXChartLookup: Sendable {

    private var wikiLevels: [String: IIDXSongLevels] = [:]
    private var textageLevels: [String: IIDXSongLevels] = [:]
    private var noteCounts: [String: [IIDXPlayType: [IIDXLevel: Int]]] = [:]

    static func load() -> IIDXChartLookup {
        var lookup = IIDXChartLookup()
        lookup.loadBEMANIWiki()
        lookup.loadTextage()
        return lookup
    }

    static func forCurrentDatabase() -> IIDXChartLookup? {
        IIDXPlayDataDatabase.current.isVersionless ? load() : nil
    }

    func difficulty(title: String, playType: IIDXPlayType, level: IIDXLevel) -> Int? {
        let compactTitle = title.compact
        for source in [wikiLevels, textageLevels] {
            let levels = playType == .single ? source[compactTitle]?.single : source[compactTitle]?.double
            if let difficulty = levels?[level], difficulty > 0 {
                return difficulty
            }
        }
        return nil
    }

    func noteCount(title: String, playType: IIDXPlayType, level: IIDXLevel) -> Int? {
        noteCounts[title.compact]?[playType]?[level]
    }

    func enrich(_ record: IIDXSongRecord) {
        record.beginnerScore = enriched(record.beginnerScore, of: record)
        record.normalScore = enriched(record.normalScore, of: record)
        record.hyperScore = enriched(record.hyperScore, of: record)
        record.anotherScore = enriched(record.anotherScore, of: record)
        record.leggendariaScore = enriched(record.leggendariaScore, of: record)
    }

    private func enriched(_ score: IIDXLevelScore, of record: IIDXSongRecord) -> IIDXLevelScore {
        var score = score
        if score.difficulty == 0,
           let difficulty = difficulty(title: record.title, playType: record.playType, level: score.level) {
            score.difficulty = difficulty
        }
        if score.djLevel == "---" || score.djLevel.isEmpty {
            score.djLevel = Self.djLevel(
                score: score.score,
                clearType: score.clearType,
                noteCount: noteCount(title: record.title, playType: record.playType, level: score.level)
            )
        }
        return score
    }

    static func djLevel(score: Int, clearType: String, noteCount: Int?) -> String {
        guard clearType != "NO PLAY", let noteCount, noteCount > 0 else { return "---" }
        let ninths = Double(score) * 9.0 / Double(noteCount * 2)
        switch ninths {
        case 8...: return "AAA"
        case 7...: return "AA"
        case 6...: return "A"
        case 5...: return "B"
        case 4...: return "C"
        case 3...: return "D"
        case 2...: return "E"
        default: return "F"
        }
    }

    // MARK: Loading

    private mutating func loadBEMANIWiki() {
        guard let database = try? BEMANIWikiDatabase.shared.getReadConnection(),
              let rows = try? database.prepare(BEMANIWikiDatabase.songTable) else { return }
        let col = BEMANIWikiDatabase.self
        for row in rows {
            let compactTitle = row[col.songTitle].compact
            guard !compactTitle.isEmpty else { continue }
            wikiLevels[compactTitle] = IIDXSongLevels(
                single: Self.levels([
                    .beginner: row[col.songSPBeginnerLevel], .normal: row[col.songSPNormalLevel],
                    .hyper: row[col.songSPHyperLevel], .another: row[col.songSPAnotherLevel],
                    .leggendaria: row[col.songSPLeggendariaLevel]
                ]),
                double: Self.levels([
                    .normal: row[col.songDPNormalLevel], .hyper: row[col.songDPHyperLevel],
                    .another: row[col.songDPAnotherLevel], .leggendaria: row[col.songDPLeggendariaLevel]
                ])
            )
            noteCounts[compactTitle] = [
                .single: Self.levels([
                    .beginner: row[col.songSPBeginnerNoteCount], .normal: row[col.songSPNormalNoteCount],
                    .hyper: row[col.songSPHyperNoteCount], .another: row[col.songSPAnotherNoteCount],
                    .leggendaria: row[col.songSPLeggendariaNoteCount]
                ]),
                .double: Self.levels([
                    .beginner: row[col.songDPBeginnerNoteCount], .normal: row[col.songDPNormalNoteCount],
                    .hyper: row[col.songDPHyperNoteCount], .another: row[col.songDPAnotherNoteCount],
                    .leggendaria: row[col.songDPLeggendariaNoteCount]
                ])
            ]
        }
    }

    private mutating func loadTextage() {
        guard let database = try? TextageDatabase.shared.getReadConnection(),
              let rows = try? database.prepare(TextageDatabase.chartTable) else { return }
        let col = TextageDatabase.self
        for row in rows {
            let compactTitle = row[col.chartTitleCompact]
            guard !compactTitle.isEmpty, textageLevels[compactTitle] == nil else { continue }
            textageLevels[compactTitle] = IIDXSongLevels(
                single: Self.levels([
                    .normal: row[col.chartSPNormal], .hyper: row[col.chartSPHyper],
                    .another: row[col.chartSPAnother], .leggendaria: row[col.chartSPLeggendaria]
                ]),
                double: Self.levels([
                    .normal: row[col.chartDPNormal], .hyper: row[col.chartDPHyper],
                    .another: row[col.chartDPAnother], .leggendaria: row[col.chartDPLeggendaria]
                ])
            )
        }
    }

    private static func levels(_ values: [IIDXLevel: Int?]) -> [IIDXLevel: Int] {
        values.compactMapValues { $0 }.filter { $0.value > 0 }
    }
}

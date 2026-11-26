import SwiftUI

enum DDRImportSummaryBuilder {

    static let lampOrder: [String] = DDRSongRecord.clearLampOrder.filter { $0 != "fail" }
    static let rankOrder: [String] = DDRSongRecord.rankOrder

    static func summary(importGroupID: String) async -> ImportSummary? {
        let reader = DDRReader()
        let groups = await reader.allImportGroups()
        guard let index = groups.firstIndex(where: { $0.id == importGroupID }) else { return nil }
        let group = groups[index]
        let earlierGroups = groups[(index + 1)...].filter { $0.version == group.version }

        let latestRecords = await reader.songRecords(for: group.id)
        var earlierRecords: [String: [DDRSongRecord]] = [:]

        var ratings: [ImportSummaryRating] = []
        var entries: [ImportSummaryEntry] = []
        var previousImportDate: Date?
        for style in DDRPlayStyle.allCases {
            let latest = latestRecords.filter { $0.styleEnum == style }
            guard !latest.isEmpty else { continue }
            var previous: [DDRSongRecord]?
            for candidate in earlierGroups {
                if earlierRecords[candidate.id] == nil {
                    earlierRecords[candidate.id] = await reader.songRecords(for: candidate.id)
                }
                let records = (earlierRecords[candidate.id] ?? []).filter { $0.styleEnum == style }
                guard !records.isEmpty else { continue }
                previous = records
                if previousImportDate.map({ candidate.date > $0 }) ?? true {
                    previousImportDate = candidate.date
                }
                break
            }
            ratings.append(ImportSummaryRating(
                name: "FLARE SKILL (\(style.abbreviation))",
                previousValue: previous.map { Double(DDRFlareSkill.total($0)) },
                value: Double(DDRFlareSkill.total(latest)),
                fractionDigits: 0
            ))
            if let previous {
                entries += personalBests(latestRecords: latest, previousRecords: previous, style: style)
            }
        }

        return ImportSummary(
            game: .ddr,
            importDate: group.date,
            previousImportDate: previousImportDate,
            ratings: ratings,
            personalBests: entries.sorted { ($0.levelValue, $1.title) > ($1.levelValue, $0.title) }
        )
    }

    static func personalBests(
        latestRecords: [DDRSongRecord],
        previousRecords: [DDRSongRecord],
        style: DDRPlayStyle
    ) -> [ImportSummaryEntry] {
        func key(_ record: DDRSongRecord) -> String {
            "\(record.songIndex.isEmpty ? record.titleCompact() : record.songIndex)|\(record.difficulty)"
        }
        let previousByKey = Dictionary(
            previousRecords.map { (key($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var entries: [ImportSummaryEntry] = []
        for record in latestRecords where record.hasScore {
            let previous = previousByKey[key(record)]
            let previousScore = previous?.score ?? 0
            let previousClearKind = previous?.clearKind.isEmpty ?? true ? nil : previous?.clearKind
            let previousRank = previous?.rank.isEmpty ?? true ? nil : previous?.rank

            let isNewScore = record.score > previousScore
            let isNewLamp = ImportSummaryRank.isImprovement(
                from: previousClearKind, to: record.clearKind, bestFirst: lampOrder
            )
            let isNewRank = ImportSummaryRank.isImprovement(
                from: previousRank, to: record.rank, bestFirst: rankOrder
            )
            guard isNewScore || isNewLamp || isNewRank else { continue }

            let difficulty = record.difficultyEnum
            entries.append(ImportSummaryEntry(
                title: record.title,
                difficulty: "\(style.abbreviation) \(difficulty.rawValue)",
                level: String(record.level),
                difficultyColor: difficulty.color,
                lampStyle: AnyShapeStyle(DDRSongRecord.clearColor(for: record.clearKind)),
                levelValue: Double(record.level),
                previousScore: isNewScore && previousScore > 0 ? previousScore : nil,
                score: isNewScore ? record.score : nil,
                lamp: isNewLamp ? ImportSummaryChange(
                    current: record.clearDisplay,
                    style: .color(DDRSongRecord.clearColor(for: record.clearKind))
                ) : nil,
                grade: isNewRank ? ImportSummaryChange(
                    current: record.rankDisplay,
                    style: .color(DDRSongRecord.rankColor(forStem: record.rank))
                ) : nil
            ))
        }
        return entries
    }
}

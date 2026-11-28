import SwiftUI

enum GITADORAImportSummaryBuilder {

    static let lampOrder: [String] = GITADORAClearType.sortedStringsWithoutNoPlay
    static let rankOrder: [String] = GITADORARank.sortedStrings

    static func summary(importGroupID: String) async -> ImportSummary? {
        let reader = GITADORAReader()
        let groups = await reader.allImportGroups()
        guard let index = groups.firstIndex(where: { $0.id == importGroupID }) else { return nil }
        let group = groups[index]
        let previousGroup = groups[(index + 1)...].first { $0.version == group.version }

        var entries: [ImportSummaryEntry] = []
        if let previousGroup {
            entries = personalBests(
                latestRecords: await reader.songRecords(for: group.id),
                previousRecords: await reader.songRecords(for: previousGroup.id)
            )
        }

        return ImportSummary(
            game: .gitadora,
            importDate: group.date,
            previousImportDate: previousGroup?.date,
            ratings: [],
            personalBests: entries
        )
    }

    static func personalBests(
        latestRecords: [GITADORASongRecord],
        previousRecords: [GITADORASongRecord]
    ) -> [ImportSummaryEntry] {
        func key(_ record: GITADORASongRecord) -> String {
            "\(record.titleCompact())|\(record.instrument)|\(record.difficulty)"
        }
        let previousByKey = Dictionary(
            previousRecords.map { (key($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var entries: [ImportSummaryEntry] = []
        for record in latestRecords {
            let previous = previousByKey[key(record)]
            let previousScore = previous?.score ?? 0
            let previousClearType = previous?.clearType == GITADORAClearType.noPlay.rawValue
                ? nil : previous?.clearType
            let previousRank = previous?.rank == GITADORARank.none.rawValue ? nil : previous?.rank

            let isNewScore = record.score > previousScore
            let isNewLamp = ImportSummaryRank.isImprovement(
                from: previousClearType, to: record.clearType, bestFirst: lampOrder
            )
            let isNewRank = ImportSummaryRank.isImprovement(
                from: previousRank, to: record.rank, bestFirst: rankOrder
            )
            guard isNewScore || isNewLamp || isNewRank else { continue }

            let difficulty = record.difficultyEnum
            let clearType = record.clearTypeEnum
            entries.append(ImportSummaryEntry(
                title: record.title,
                difficulty: "\(record.instrumentEnum.displayName) \(difficulty.abbreviation)",
                level: record.level,
                difficultyColor: difficulty.color,
                lampStyle: AnyShapeStyle(clearType.color),
                levelValue: record.levelValue,
                previousScore: isNewScore && previousScore > 0 ? previousScore : nil,
                score: isNewScore ? record.score : nil,
                lamp: isNewLamp ? ImportSummaryChange(
                    current: clearType.abbreviation,
                    style: .color(clearType.color)
                ) : nil,
                grade: isNewRank ? ImportSummaryChange(
                    current: record.rank,
                    style: .color(GITADORARank.color(for: record.rank))
                ) : nil
            ))
        }
        return entries.sorted { ($0.levelValue, $1.title) > ($1.levelValue, $0.title) }
    }
}

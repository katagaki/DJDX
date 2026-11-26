import SwiftUI

enum PopnImportSummaryBuilder {

    static let lampOrder: [String] = PopnClearType.sorted.dropLast(2).map(\.rawValue)
    static let gradeOrder: [String] = PopnRank.sortedStrings

    static func summary(importGroupID: String) async -> ImportSummary? {
        let reader = PopnReader()
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
            game: .popn,
            importDate: group.date,
            previousImportDate: previousGroup?.date,
            ratings: [],
            personalBests: entries
        )
    }

    static func personalBests(
        latestRecords: [PopnSongRecord],
        previousRecords: [PopnSongRecord]
    ) -> [ImportSummaryEntry] {
        func key(_ record: PopnSongRecord) -> String {
            "\(record.titleCompact())|\(record.genre)|\(record.difficulty)"
        }
        let previousByKey = Dictionary(
            previousRecords.map { (key($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var entries: [ImportSummaryEntry] = []
        for record in latestRecords {
            let previous = previousByKey[key(record)]
            let previousScore = previous?.score ?? 0
            let previousClearType = previous.map(\.clearType).flatMap { $0 == .noPlay ? nil : $0.rawValue }
            let previousRank = previous?.rank == PopnRank.none.rawValue ? nil : previous?.rank

            let isNewScore = record.score > previousScore
            let isNewLamp = ImportSummaryRank.isImprovement(
                from: previousClearType, to: record.clearType.rawValue, bestFirst: lampOrder
            )
            let isNewRank = ImportSummaryRank.isImprovement(
                from: previousRank, to: record.rank, bestFirst: gradeOrder
            )
            guard isNewScore || isNewLamp || isNewRank else { continue }

            let difficulty = record.difficultyEnum
            let medal = record.medalEnum
            let rank = record.rankEnum
            entries.append(ImportSummaryEntry(
                title: record.title,
                difficulty: difficulty.rawValue,
                level: String(record.level),
                difficultyColor: difficulty.color,
                lampStyle: AnyShapeStyle(medal.clearType.color),
                levelValue: Double(record.level),
                previousScore: isNewScore && previousScore > 0 ? previousScore : nil,
                score: isNewScore ? record.score : nil,
                lamp: isNewLamp ? ImportSummaryChange(
                    current: medal.abbreviation,
                    style: .color(medal.clearType.color)
                ) : nil,
                grade: isNewRank ? ImportSummaryChange(
                    current: rank.rawValue,
                    style: .color(rank.color)
                ) : nil
            ))
        }
        return entries.sorted { ($0.levelValue, $1.title) > ($1.levelValue, $0.title) }
    }
}

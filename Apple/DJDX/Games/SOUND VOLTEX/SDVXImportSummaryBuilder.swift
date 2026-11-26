import SwiftUI

enum SDVXImportSummaryBuilder {

    static let lampOrder: [String] = SDVXClearType.sortedStrings.dropLast(2).map { $0 }
    static let gradeOrder: [String] = SDVXGrade.sortedStrings

    static func summary(importGroupID: String) async -> ImportSummary? {
        let reader = SDVXReader()
        let groups = await reader.allImportGroups()
        guard let index = groups.firstIndex(where: { $0.id == importGroupID }) else { return nil }
        let group = groups[index]
        let previousGroup = groups[(index + 1)...].first { $0.version == group.version }

        let latestRecords = await reader.songRecords(for: group.id)
        let previousRecords = if let previousGroup {
            await reader.songRecords(for: previousGroup.id)
        } else {
            [SDVXSongRecord]()
        }

        let volforce = ImportSummaryRating(
            name: "VOLFORCE",
            previousValue: previousGroup == nil ? nil : SDVXVolforce.total(previousRecords),
            value: SDVXVolforce.total(latestRecords),
            fractionDigits: 3
        )

        return ImportSummary(
            game: .sdvx,
            importDate: group.date,
            previousImportDate: previousGroup?.date,
            ratings: [volforce],
            personalBests: previousGroup == nil ? [] : personalBests(
                latestRecords: latestRecords, previousRecords: previousRecords
            )
        )
    }

    static func personalBests(
        latestRecords: [SDVXSongRecord],
        previousRecords: [SDVXSongRecord]
    ) -> [ImportSummaryEntry] {
        func key(_ record: SDVXSongRecord) -> String {
            "\(record.titleCompact())|\(record.difficulty)"
        }
        let previousByKey = Dictionary(
            previousRecords.map { (key($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var entries: [ImportSummaryEntry] = []
        for record in latestRecords {
            let previous = previousByKey[key(record)]
            let previousScore = previous?.highScore ?? 0
            let previousClearType = previous?.clearType == SDVXClearType.noPlay.rawValue ? nil : previous?.clearType
            let previousGrade = previous?.grade == SDVXGrade.none.rawValue ? nil : previous?.grade

            let isNewScore = record.highScore > previousScore
            let isNewLamp = ImportSummaryRank.isImprovement(
                from: previousClearType, to: record.clearType, bestFirst: lampOrder
            )
            let isNewGrade = ImportSummaryRank.isImprovement(
                from: previousGrade, to: record.grade, bestFirst: gradeOrder
            )
            guard isNewScore || isNewLamp || isNewGrade else { continue }

            let difficulty = record.difficultyEnum
            entries.append(ImportSummaryEntry(
                title: record.title,
                difficulty: difficulty.rawValue,
                level: record.level,
                difficultyColor: difficulty.color,
                lampStyle: AnyShapeStyle(record.clearTypeEnum.color),
                levelValue: Double(record.level) ?? 0.0,
                previousScore: isNewScore && previousScore > 0 ? previousScore : nil,
                score: isNewScore ? record.highScore : nil,
                lamp: isNewLamp ? ImportSummaryChange(
                    current: record.clearTypeEnum.abbreviation,
                    style: .color(record.clearTypeEnum.color)
                ) : nil,
                grade: isNewGrade ? ImportSummaryChange(
                    current: record.grade,
                    style: .sdvxGrade
                ) : nil
            ))
        }
        return entries.sorted { ($0.levelValue, $1.title) > ($1.levelValue, $0.title) }
    }
}

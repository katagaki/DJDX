import SwiftUI

enum PolarisChordImportSummaryBuilder {

    static let lampOrder: [String] = PolarisChordClearType.sorted.dropLast(2).map(\.rawValue)
    static let gradeOrder: [String] = PolarisChordGrade.sortedStrings

    static func summary(importGroupID: String) async -> ImportSummary? {
        let reader = PolarisChordReader()
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
            game: .polarisChord,
            importDate: group.date,
            previousImportDate: previousGroup?.date,
            ratings: [],
            personalBests: entries
        )
    }

    static func personalBests(
        latestRecords: [PolarisChordSongRecord],
        previousRecords: [PolarisChordSongRecord]
    ) -> [ImportSummaryEntry] {
        func key(_ record: PolarisChordSongRecord) -> String {
            "\(record.titleCompact())|\(record.difficulty)"
        }
        let previousByKey = Dictionary(
            previousRecords.map { (key($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var entries: [ImportSummaryEntry] = []
        for record in latestRecords {
            let previous = previousByKey[key(record)]
            let previousScore = previous?.score ?? 0
            let previousClearType = previous?.clearType == PolarisChordClearType.noPlay.rawValue
                ? nil : previous?.clearType
            let previousGrade = previous?.grade == PolarisChordGrade.none.rawValue ? nil : previous?.grade

            let isNewScore = record.score > previousScore
            let isNewLamp = ImportSummaryRank.isImprovement(
                from: previousClearType, to: record.clearType, bestFirst: lampOrder
            )
            let isNewGrade = ImportSummaryRank.isImprovement(
                from: previousGrade, to: record.grade, bestFirst: gradeOrder
            )
            guard isNewScore || isNewLamp || isNewGrade else { continue }

            let difficulty = record.difficultyEnum
            let clearType = PolarisChordClearType(rawValue: record.clearType) ?? .unknown
            entries.append(ImportSummaryEntry(
                title: record.title,
                difficulty: difficulty.rawValue,
                level: record.level,
                difficultyColor: difficulty.color,
                lampStyle: AnyShapeStyle(clearType.color),
                levelValue: Double(record.level.filter { $0.isNumber || $0 == "." }) ?? 0.0,
                previousScore: isNewScore && previousScore > 0 ? previousScore : nil,
                score: isNewScore ? record.score : nil,
                lamp: isNewLamp ? ImportSummaryChange(
                    current: clearType.abbreviation,
                    style: .color(clearType.color)
                ) : nil,
                grade: isNewGrade ? ImportSummaryChange(
                    current: record.grade,
                    style: .polarisChordGrade
                ) : nil
            ))
        }
        return entries.sorted { ($0.levelValue, $1.title) > ($1.levelValue, $0.title) }
    }
}

import SwiftUI

enum IIDXImportSummaryBuilder {

    static let lampOrder: [String] = IIDXClearType.ascending.reversed().dropLast(2).map(\.rawValue)
    static let djLevelOrder: [String] = IIDXDJLevel.sorted.reversed().map(\.rawValue)

    static func summary(importGroupID: String) async -> ImportSummary? {
        let reader = IIDXReader()
        let groups = await reader.allImportGroups()
        guard let index = groups.firstIndex(where: { $0.id == importGroupID }) else { return nil }
        let group = groups[index]
        let earlierGroups = groups[..<index]
            .filter { $0.iidxVersion == group.iidxVersion }
            .reversed()

        var entries: [ImportSummaryEntry] = []
        var previousImportDate: Date?
        for playType in [IIDXPlayType.single, .double] {
            let latestRecords = await reader.songRecords(for: group.id, playType: playType)
            guard !latestRecords.isEmpty else { continue }
            for candidate in earlierGroups {
                let previousRecords = await reader.songRecords(for: candidate.id, playType: playType)
                guard !previousRecords.isEmpty else { continue }
                if previousImportDate.map({ candidate.importDate > $0 }) ?? true {
                    previousImportDate = candidate.importDate
                }
                entries += personalBests(latestRecords: latestRecords,
                                         previousRecords: previousRecords,
                                         playType: playType)
                break
            }
        }

        return ImportSummary(
            importDate: group.importDate,
            previousImportDate: previousImportDate,
            ratings: [],
            personalBests: entries.sorted { ($0.levelValue, $1.title) > ($1.levelValue, $0.title) }
        )
    }

    static func personalBests(
        latestRecords: [IIDXSongRecord],
        previousRecords: [IIDXSongRecord],
        playType: IIDXPlayType
    ) -> [ImportSummaryEntry] {
        let previousByKey = Dictionary(
            previousRecords.map { (AnalyticsModel.matchKey(for: $0), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let levels: [(IIDXLevel, KeyPath<IIDXSongRecord, IIDXLevelScore>)] = [
            (.beginner, \.beginnerScore),
            (.normal, \.normalScore),
            (.hyper, \.hyperScore),
            (.another, \.anotherScore),
            (.leggendaria, \.leggendariaScore)
        ]

        var entries: [ImportSummaryEntry] = []
        for record in latestRecords {
            let previousRecord = previousByKey[AnalyticsModel.matchKey(for: record)]
            for (level, keyPath) in levels {
                let latest = record[keyPath: keyPath]
                guard latest.difficulty > 0 else { continue }
                let previous = previousRecord?[keyPath: keyPath]
                let previousScore = previous?.score ?? 0
                let previousClearType = previous?.clearType == IIDXClearType.noPlay.rawValue ? nil : previous?.clearType
                let previousDJLevel = previous?.djLevel == IIDXDJLevel.none.rawValue ? nil : previous?.djLevel

                let isNewScore = latest.score > previousScore
                let isNewLamp = ImportSummaryRank.isImprovement(
                    from: previousClearType, to: latest.clearType, bestFirst: lampOrder
                )
                let isNewDJLevel = ImportSummaryRank.isImprovement(
                    from: previousDJLevel, to: latest.djLevel, bestFirst: djLevelOrder
                )
                guard isNewScore || isNewLamp || isNewDJLevel else { continue }

                entries.append(ImportSummaryEntry(
                    title: record.title,
                    chart: "\(playType.displayName())\(level.code()) \(latest.difficulty)",
                    chartColor: color(for: level),
                    levelValue: Double(latest.difficulty),
                    previousScore: isNewScore && previousScore > 0 ? previousScore : nil,
                    score: isNewScore ? latest.score : nil,
                    lamp: isNewLamp ? ImportSummaryChange(
                        previous: previousClearType.map { IIDXClearType.abbreviation(for: $0) },
                        current: IIDXClearType.abbreviation(for: latest.clearType),
                        color: IIDXClearType.color(for: latest.clearType)
                    ) : nil,
                    grade: isNewDJLevel ? ImportSummaryChange(
                        previous: previousDJLevel,
                        current: latest.djLevel,
                        color: IIDXDJLevel.color(for: latest.djLevel)
                    ) : nil
                ))
            }
        }
        return entries
    }

    static func color(for level: IIDXLevel) -> Color {
        switch level {
        case .beginner: return .green
        case .normal: return .blue
        case .hyper: return .orange
        case .another: return .red
        case .leggendaria: return .purple
        default: return .gray
        }
    }
}

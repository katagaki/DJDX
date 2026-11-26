import SwiftUI

enum IIDXImportSummaryBuilder {

    static let lampOrder: [String] = IIDXClearType.ascending.reversed().dropLast(2).map(\.rawValue)
    static let djLevelOrder: [String] = IIDXDJLevel.sorted.reversed().map(\.rawValue)
    static var levels: [(IIDXLevel, KeyPath<IIDXSongRecord, IIDXLevelScore>)] {
        [
            (.beginner, \.beginnerScore),
            (.normal, \.normalScore),
            (.hyper, \.hyperScore),
            (.another, \.anotherScore),
            (.leggendaria, \.leggendariaScore)
        ]
    }

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

        var notesRadars: [ImportSummaryNotesRadar] = []
        for playType in [IIDXPlayType.single, .double] {
            guard let radar = await reader.notesRadar(for: group.id, playType: playType) else { continue }
            var previousRadar: RadarData?
            for candidate in earlierGroups {
                if let candidateRadar = await reader.notesRadar(for: candidate.id, playType: playType) {
                    previousRadar = candidateRadar
                    break
                }
            }
            notesRadars.append(ImportSummaryNotesRadar(
                playType: playType == .single ? "SP" : "DP", radar: radar, previousRadar: previousRadar
            ))
        }

        return ImportSummary(
            game: .iidx,
            importDate: group.importDate,
            previousImportDate: previousImportDate,
            ratings: [],
            personalBests: entries.sorted { ($0.levelValue, $1.title) > ($1.levelValue, $0.title) },
            notesRadars: notesRadars
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
                    difficulty: "\(playType == .single ? "SP" : "DP") \(name(for: level))",
                    level: String(latest.difficulty),
                    difficultyColor: color(for: level),
                    lampStyle: ShareCardEntry.iidxLampStyle(for: latest.clearType),
                    levelValue: Double(latest.difficulty),
                    previousScore: isNewScore && previousScore > 0 ? previousScore : nil,
                    score: isNewScore ? latest.score : nil,
                    lamp: isNewLamp ? ImportSummaryChange(
                        current: latest.clearType,
                        style: .iidxClearType
                    ) : nil,
                    grade: isNewDJLevel ? ImportSummaryChange(
                        current: latest.djLevel,
                        style: .iidxDJLevel
                    ) : nil,
                    titleStyle: .iidx(version: record.version, level: level)
                ))
            }
        }
        return entries
    }

    static func name(for level: IIDXLevel) -> String {
        switch level {
        case .beginner: return "BEGINNER"
        case .normal: return "NORMAL"
        case .hyper: return "HYPER"
        case .another: return "ANOTHER"
        case .leggendaria: return "LEGGENDARIA"
        default: return ""
        }
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

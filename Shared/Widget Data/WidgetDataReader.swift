import Foundation
import SQLite

final class WidgetDataReader: Sendable {
    static let shared = WidgetDataReader()

    private let database = IIDXPlayDataDatabase.shared

    // MARK: - Clear Type / DJ Level

    func clearType(versionRaw: Int, playTypeRaw: String) -> WidgetClearTypeSnapshot {
        let aggregate = aggregate(versionRaw: versionRaw, playTypeRaw: playTypeRaw)
        return WidgetClearTypeSnapshot(
            dataPerDifficulty: aggregate.clearTypeData,
            trendData: aggregate.clearTypeTrends,
            playType: playTypeRaw,
            lastUpdated: .now
        )
    }

    func djLevel(versionRaw: Int, playTypeRaw: String) -> WidgetDJLevelSnapshot {
        let aggregate = aggregate(versionRaw: versionRaw, playTypeRaw: playTypeRaw)
        return WidgetDJLevelSnapshot(
            dataPerDifficulty: aggregate.djLevelData,
            trendData: aggregate.djLevelTrends,
            playType: playTypeRaw,
            lastUpdated: .now
        )
    }

    private struct Aggregate {
        let clearTypeData: [Int: [String: Int]]
        let djLevelData: [Int: [String: Int]]
        let clearTypeTrends: [String: [Int: [String: Int]]]
        let djLevelTrends: [String: [Int: [String: Int]]]
    }

    private func aggregate(versionRaw: Int, playTypeRaw: String) -> Aggregate {
        var clearTypeData: [Int: [String: Int]] = [:]
        var djLevelData: [Int: [String: Int]] = [:]
        if let currentID = currentImportGroupID() {
            let counts = aggregatedCounts(for: [currentID], playTypeRaw: playTypeRaw)
            clearTypeData = counts.clearType[currentID] ?? [:]
            djLevelData = counts.djLevel[currentID] ?? [:]
        }

        let versionGroups = versionImportGroups(versionRaw: versionRaw)
        let ids = versionGroups.map(\.id)
        let idToDate = Dictionary(uniqueKeysWithValues: versionGroups.map { ($0.id, $0.date) })
        let trends = aggregatedCounts(for: ids, playTypeRaw: playTypeRaw)

        var clearTypeTrends: [String: [Int: [String: Int]]] = [:]
        var djLevelTrends: [String: [Int: [String: Int]]] = [:]
        for igID in ids {
            guard let date = idToDate[igID] else { continue }
            let dateKey = String(date.timeIntervalSince1970)
            if let clearType = trends.clearType[igID] {
                clearTypeTrends[dateKey] = clearType
            }
            if let djLevel = trends.djLevel[igID] {
                djLevelTrends[dateKey] = djLevel
            }
        }

        return Aggregate(
            clearTypeData: clearTypeData,
            djLevelData: djLevelData,
            clearTypeTrends: clearTypeTrends,
            djLevelTrends: djLevelTrends
        )
    }

    // MARK: - Tower

    func tower() -> WidgetTowerSnapshot {
        let entries = allTowerEntries()
        let totalKeys = entries.reduce(0) { $0 + $1.keyCount } / 100
        let totalScratch = entries.reduce(0) { $0 + $1.scratchCount } / 100
        let latestEntries = Array(entries.prefix(3))
        return WidgetTowerSnapshot(
            totalKeyCount: totalKeys,
            totalScratchCount: totalScratch,
            latestEntries: latestEntries,
            lastUpdated: .now
        )
    }

    // MARK: - Radar

    func radar() -> WidgetRadarSnapshot {
        let defaults = SharedContainer.defaults
        var spData: WidgetRadarData?
        var dpData: WidgetRadarData?

        if defaults.object(forKey: "NotesRadar.SP.Notes") != nil {
            spData = WidgetRadarData(
                notes: defaults.double(forKey: "NotesRadar.SP.Notes"),
                chord: defaults.double(forKey: "NotesRadar.SP.Chord"),
                peak: defaults.double(forKey: "NotesRadar.SP.Peak"),
                charge: defaults.double(forKey: "NotesRadar.SP.Charge"),
                scratch: defaults.double(forKey: "NotesRadar.SP.Scratch"),
                soflan: defaults.double(forKey: "NotesRadar.SP.Soflan")
            )
        }
        if defaults.object(forKey: "NotesRadar.DP.Notes") != nil {
            dpData = WidgetRadarData(
                notes: defaults.double(forKey: "NotesRadar.DP.Notes"),
                chord: defaults.double(forKey: "NotesRadar.DP.Chord"),
                peak: defaults.double(forKey: "NotesRadar.DP.Peak"),
                charge: defaults.double(forKey: "NotesRadar.DP.Charge"),
                scratch: defaults.double(forKey: "NotesRadar.DP.Scratch"),
                soflan: defaults.double(forKey: "NotesRadar.DP.Soflan")
            )
        }

        return WidgetRadarSnapshot(spData: spData, dpData: dpData, lastUpdated: .now)
    }

    // MARK: - Queries

    private func currentImportGroupID() -> String? {
        guard let connection = try? database.getReadConnection() else { return nil }
        let table = IIDXPlayDataDatabase.importGroupTable
        let importDate = IIDXPlayDataDatabase.igImportDate
        let id = IIDXPlayDataDatabase.igID

        let selectedDate = Date.now
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let dayQuery = table
            .filter(importDate >= startOfDay.timeIntervalSince1970
                    && importDate < startOfNextDay.timeIntervalSince1970)
            .order(importDate.asc)
            .limit(1)
        if let row = try? connection.pluck(dayQuery) {
            return row[id]
        }

        guard let rows = try? connection.prepare(table.order(importDate.asc)) else { return nil }
        var closest: String?
        for row in rows {
            if Date(timeIntervalSince1970: row[importDate]) <= selectedDate {
                closest = row[id]
            } else {
                break
            }
        }
        return closest
    }

    private func versionImportGroups(versionRaw: Int) -> [(id: String, date: Date)] {
        guard let connection = try? database.getReadConnection() else { return [] }
        let query = IIDXPlayDataDatabase.importGroupTable
            .filter(IIDXPlayDataDatabase.igIIDXVersion == versionRaw)
            .order(IIDXPlayDataDatabase.igImportDate.asc)
        return (try? connection.prepare(query).map {
            ($0[IIDXPlayDataDatabase.igID], Date(timeIntervalSince1970: $0[IIDXPlayDataDatabase.igImportDate]))
        }) ?? []
    }

    private func allTowerEntries() -> [WidgetTowerEntry] {
        guard let connection = try? database.getReadConnection() else { return [] }
        let query = IIDXPlayDataDatabase.towerEntryTable.order(IIDXPlayDataDatabase.tePlayDate.desc)
        return (try? connection.prepare(query).map {
            WidgetTowerEntry(
                playDate: Date(timeIntervalSince1970: $0[IIDXPlayDataDatabase.tePlayDate]),
                keyCount: $0[IIDXPlayDataDatabase.teKeyCount],
                scratchCount: $0[IIDXPlayDataDatabase.teScratchCount]
            )
        }) ?? []
    }

    private struct LevelColumns {
        let difficulty: SQLite.Expression<Int>
        let clearType: SQLite.Expression<String>
        let djLevel: SQLite.Expression<String>
        let score: SQLite.Expression<Int>
    }

    // swiftlint:disable:next function_body_length
    private func aggregatedCounts(
        for importGroupIDs: [String],
        playTypeRaw: String
    ) -> (clearType: [String: [Int: [String: Int]]], djLevel: [String: [Int: [String: Int]]]) {
        guard let connection = try? database.getReadConnection() else {
            return ([:], [:])
        }
        let cols = IIDXPlayDataDatabase.self

        var clearTypeResult: [String: [Int: [String: Int]]] = [:]
        var djLevelResult: [String: [Int: [String: Int]]] = [:]

        let levelColumns: [LevelColumns] = [
            LevelColumns(difficulty: cols.srBeginnerDifficulty, clearType: cols.srBeginnerClearType,
                         djLevel: cols.srBeginnerDJLevel, score: cols.srBeginnerScore),
            LevelColumns(difficulty: cols.srNormalDifficulty, clearType: cols.srNormalClearType,
                         djLevel: cols.srNormalDJLevel, score: cols.srNormalScore),
            LevelColumns(difficulty: cols.srHyperDifficulty, clearType: cols.srHyperClearType,
                         djLevel: cols.srHyperDJLevel, score: cols.srHyperScore),
            LevelColumns(difficulty: cols.srAnotherDifficulty, clearType: cols.srAnotherClearType,
                         djLevel: cols.srAnotherDJLevel, score: cols.srAnotherScore),
            LevelColumns(difficulty: cols.srLeggendariaDifficulty, clearType: cols.srLeggendariaClearType,
                         djLevel: cols.srLeggendariaDJLevel, score: cols.srLeggendariaScore)
        ]

        let table = IIDXPlayDataDatabase.songRecordTable
            .filter(importGroupIDs.contains(cols.srImportGroupID) && cols.srPlayType == playTypeRaw)

        for level in levelColumns {
            let clearQuery = table
                .select(cols.srImportGroupID, level.difficulty, level.clearType, level.score.count)
                .filter(level.difficulty > 0 && level.clearType != "NO PLAY" && level.score > 0)
                .group(cols.srImportGroupID, level.difficulty, level.clearType)

            if let rows = try? connection.prepare(clearQuery) {
                for row in rows {
                    let igID = row[cols.srImportGroupID]
                    let diff = row[level.difficulty]
                    let clearType = row[level.clearType]
                    let count = row[level.score.count]
                    clearTypeResult[igID, default: [:]][diff, default: [:]][clearType, default: 0] += count
                }
            }

            let djQuery = table
                .select(cols.srImportGroupID, level.difficulty, level.djLevel, level.djLevel.count)
                .filter(level.difficulty > 0 && level.djLevel != "---")
                .group(cols.srImportGroupID, level.difficulty, level.djLevel)

            if let rows = try? connection.prepare(djQuery) {
                for row in rows {
                    let igID = row[cols.srImportGroupID]
                    let diff = row[level.difficulty]
                    let djLevel = row[level.djLevel]
                    let count = row[level.djLevel.count]
                    djLevelResult[igID, default: [:]][diff, default: [:]][djLevel, default: 0] += count
                }
            }
        }

        return (clearTypeResult, djLevelResult)
    }
}

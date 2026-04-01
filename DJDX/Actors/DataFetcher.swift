//
//  DataFetcher.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/05.
//

import Foundation
import SQLite

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
actor DataFetcher {

    var previousFilters: FilterOptions?
    var previousSortOptions: SortOptions?

    var importGroupID: String?
    var allSongRecords: [IIDXSongRecord] = []
    var filteredSongRecords: [IIDXSongRecord] = []
    var sortedSongRecords: [IIDXSongRecord] = []

    var songs: [IIDXSong] = []
    var songNoteCounts: [String: IIDXNoteCount] = [:]

    // MARK: Import Groups

    func importGroup(for selectedDate: Date) -> ImportGroup? {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return nil }
        let table = PlayDataDatabase.importGroupTable
        let col = PlayDataDatabase.self

        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let query = table
            .filter(col.igImportDate >= startOfDay.timeIntervalSince1970
                    && col.igImportDate < startOfNextDay.timeIntervalSince1970)
            .order(col.igImportDate.asc)
            .limit(1)

        if let row = try? database.pluck(query) {
            return Self.importGroup(from: row)
        }

        // Fallback: closest earlier import group
        let allQuery = table.order(col.igImportDate.asc)
        guard let rows = try? database.prepare(allQuery) else { return nil }

        var closestGroup: ImportGroup?
        for row in rows {
            let group = Self.importGroup(from: row)
            if group.importDate <= selectedDate {
                closestGroup = group
            } else {
                break
            }
        }
        return closestGroup
    }

    func importGroupID(for selectedDate: Date) -> String? {
        importGroup(for: selectedDate)?.id
    }

    func allImportGroups() -> [ImportGroup] {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.importGroupTable.order(PlayDataDatabase.igImportDate.asc)
        return (try? database.prepare(query).map { Self.importGroup(from: $0) }) ?? []
    }

    func allImportGroupsSortedByDateDescending() -> [ImportGroup] {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.importGroupTable.order(PlayDataDatabase.igImportDate.desc)
        return (try? database.prepare(query).map { Self.importGroup(from: $0) }) ?? []
    }

    // MARK: Song Records

    func songRecords(for importGroupID: String) -> [IIDXSongRecord] {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.songRecordTable
            .filter(PlayDataDatabase.srImportGroupID == importGroupID)
            .order(PlayDataDatabase.srTitle.asc)
        return (try? database.prepare(query).map { Self.songRecord(from: $0) }) ?? []
    }

    func songRecords(for importGroupID: String, playType: IIDXPlayType) -> [IIDXSongRecord] {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.songRecordTable
            .filter(PlayDataDatabase.srImportGroupID == importGroupID
                    && PlayDataDatabase.srPlayType == playType.rawValue)
            .order(PlayDataDatabase.srTitle.asc)
        return (try? database.prepare(query).map { Self.songRecord(from: $0) }) ?? []
    }

    func songRecordsForSong(title: String) -> [IIDXSongRecord] {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.songRecordTable
            .filter(PlayDataDatabase.srTitle == title)
        return (try? database.prepare(query).map { Self.songRecord(from: $0) }) ?? []
    }

    func songRecordImportGroupIDs(for title: String) -> [String] {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.songRecordTable
            .select(PlayDataDatabase.srImportGroupID)
            .filter(PlayDataDatabase.srTitle == title)
        return (try? database.prepare(query).map { $0[PlayDataDatabase.srImportGroupID] }) ?? []
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func songRecords(
        on playDataDate: Date,
        filters: FilterOptions?,
        sortOptions: SortOptions?
    ) -> [IIDXSongRecord]? {

        guard let importGroup = importGroup(for: playDataDate) else {
            return nil
        }

        if importGroupID != importGroup.id {
            importGroupID = importGroup.id
            previousFilters = nil
            previousSortOptions = nil

            allSongRecords = songRecords(for: importGroup.id)

            if songs.isEmpty {
                songs = fetchAllSongs()
            }
            if songNoteCounts.isEmpty {
                songNoteCounts = songs
                    .reduce(into: [:]) { partialResult, song in
                        partialResult[song.titleCompact()] = song.spNoteCount
                    }
            }
        }
        var songRecords: [IIDXSongRecord] = []

        if filters != previousFilters, let filters {
            debugPrint("Filters were changed, filtering")

            filteredSongRecords = allSongRecords.filter({
                $0.playType == filters.playType
            })

            if !filters.versions.isEmpty {
                filteredSongRecords.removeAll { !filters.versions.contains($0.version) }
            }

            if filters.onlyPlayDataWithScores {
                filteredSongRecords.removeAll { songRecord in
                    songRecord.beginnerScore.score == 0 &&
                    songRecord.normalScore.score == 0 &&
                    songRecord.hyperScore.score == 0 &&
                    songRecord.anotherScore.score == 0 &&
                    songRecord.leggendariaScore.score == 0
                }
            }

            let hasLevelFilter = !filters.levels.isEmpty
            let hasDifficultyFilter = !filters.difficulties.isEmpty
            let hasClearTypeFilter = !filters.clearTypes.isEmpty
            let hasDJLevelFilter = !filters.djLevels.isEmpty
            let difficultyRawValues = Set(filters.difficulties.map(\.rawValue))
            let clearTypeRawValues = Set(filters.clearTypes.map(\.rawValue))
            let djLevelRawValues = Set(filters.djLevels.map(\.rawValue))

            if hasLevelFilter || hasDifficultyFilter || hasClearTypeFilter || hasDJLevelFilter {
                filteredSongRecords.removeAll { songRecord in
                    let scores = songRecord.scores()
                    let hasMatchingScore = scores.contains { score in
                        if hasLevelFilter, !filters.levels.contains(score.level) {
                            return false
                        }
                        if hasDifficultyFilter, !difficultyRawValues.contains(score.difficulty) {
                            return false
                        }
                        if hasClearTypeFilter, !clearTypeRawValues.contains(score.clearType) {
                            return false
                        }
                        if hasDJLevelFilter, !djLevelRawValues.contains(score.djLevel) {
                            return false
                        }
                        if filters.onlyPlayDataWithScores, score.score == 0 {
                            return false
                        }
                        return true
                    }
                    return !hasMatchingScore
                }
            }

            songRecords = filteredSongRecords
        } else {
            debugPrint("Filters were not changed, using previously filtered song records")
            songRecords = filteredSongRecords
        }

        if filters != previousFilters || sortOptions != previousSortOptions, let sortOptions {
            debugPrint("Filters or sort options were changed, sorting")

            sortedSongRecords = songRecords
            var songLevelScores: [IIDXSongRecord: IIDXLevelScore] = [:]

            if sortOptions.mode != .title && sortOptions.mode != .lastPlayDate {
                if let levels = filters?.levels,
                   levels.count == 1,
                   let level = levels.first,
                   let keyPath = scoreKeyPath(for: level) {
                    songLevelScores = sortedSongRecords.reduce(into: [:], { partialResult, songRecord in
                        partialResult[songRecord] = songRecord[keyPath: keyPath]
                    })
                } else if let difficulties = filters?.difficulties,
                          difficulties.count == 1,
                          let difficulty = difficulties.first {
                    songLevelScores = sortedSongRecords.reduce(into: [:], { partialResult, songRecord in
                        partialResult[songRecord] = songRecord.score(for: difficulty)
                    })
                }
            }

            let isAscending = sortOptions.order == .ascending

            switch sortOptions.mode {
            case .title:
                sortedSongRecords.sort { lhs, rhs in
                    isAscending ? lhs.title < rhs.title : lhs.title > rhs.title
                }
            case .clearType:
                let clearTypes = IIDXClearType.sortedStrings
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        let lhsIndex = clearTypes.firstIndex(of: lhs.value.clearType)
                        let rhsIndex = clearTypes.firstIndex(of: rhs.value.clearType)
                        if lhsIndex == rhsIndex {
                            return lhs.key.title < rhs.key.title
                        } else {
                            if let lhsIndex, let rhsIndex {
                                return isAscending ? lhsIndex < rhsIndex : lhsIndex > rhsIndex
                            } else {
                                return lhsIndex != nil
                            }
                        }
                    })
                    .map({ $0.key })
            case .djLevel:
                let djLevels = IIDXDJLevel.sorted
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        let lhsIndex = djLevels.firstIndex(of: lhs.value.djLevelEnum())
                        let rhsIndex = djLevels.firstIndex(of: rhs.value.djLevelEnum())
                        if lhsIndex == rhsIndex {
                            return lhs.key.title < rhs.key.title
                        } else {
                            if let lhsIndex, let rhsIndex {
                                return isAscending ? lhsIndex < rhsIndex : lhsIndex > rhsIndex
                            } else {
                                if lhsIndex == nil && rhsIndex != nil {
                                    return false
                                } else {
                                    return true
                                }
                            }
                        }
                    })
                    .map({ $0.key })
            case .scoreRate:
                if songNoteCounts.count > 0 {
                    sortedSongRecords = songLevelScores
                        .sorted(by: { lhs, rhs in
                            let lhsSong = songNoteCounts[lhs.key.titleCompact()]
                            let rhsSong = songNoteCounts[rhs.key.titleCompact()]
                            if lhsSong == nil && rhsSong != nil {
                                return false
                            } else if lhsSong != nil && rhsSong == nil {
                                return true
                            } else if let lhsSong, let rhsSong {
                                if let lhsNoteCount = lhsSong.noteCount(for: lhs.value.level),
                                   let rhsNoteCount = rhsSong.noteCount(for: rhs.value.level) {
                                    let lhsScoreRate = Float(lhs.value.score) / Float(lhsNoteCount * 2)
                                    let rhsScoreRate = Float(rhs.value.score) / Float(rhsNoteCount * 2)
                                    if lhsScoreRate.isZero && rhsScoreRate > .zero {
                                        return false
                                    } else if rhsScoreRate.isZero && rhsScoreRate > .zero {
                                        return true
                                    } else if lhsScoreRate.isZero && rhsScoreRate.isZero {
                                        return lhs.key.title < rhs.key.title
                                    } else {
                                        return isAscending ? lhsScoreRate < rhsScoreRate
                                            : lhsScoreRate > rhsScoreRate
                                    }
                                } else {
                                    return false
                                }
                            } else {
                                return lhs.key.title < rhs.key.title
                            }
                        })
                        .map({ $0.key })
                }
            case .score:
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        if lhs.value.score == rhs.value.score {
                            return lhs.key.title < rhs.key.title
                        } else {
                            return isAscending ? lhs.value.score < rhs.value.score
                                : lhs.value.score > rhs.value.score
                        }
                    })
                    .map({ $0.key })
            case .missCount:
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        if lhs.value.missCount == rhs.value.missCount {
                            return lhs.key.title < rhs.key.title
                        } else {
                            return isAscending ? lhs.value.missCount < rhs.value.missCount
                                : lhs.value.missCount > rhs.value.missCount
                        }
                    })
                    .map({ $0.key })
            case .difficulty:
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        if lhs.value.difficulty == rhs.value.difficulty {
                            return lhs.key.title < rhs.key.title
                        } else {
                            return isAscending ? lhs.value.difficulty < rhs.value.difficulty
                                : lhs.value.difficulty > rhs.value.difficulty
                        }
                    })
                    .map({ $0.key })
            case .lastPlayDate:
                sortedSongRecords.sort { lhs, rhs in
                    isAscending ? lhs.lastPlayDate < rhs.lastPlayDate
                        : lhs.lastPlayDate > rhs.lastPlayDate
                }
            }

            songRecords = sortedSongRecords
        } else {
            debugPrint("Filters or sort options were not changed, using previously sorted song records")
            songRecords = sortedSongRecords
        }

        previousFilters = filters
        previousSortOptions = sortOptions
        return songRecords
    }

    // MARK: Song Metadata

    func songCompactTitles() -> [String: IIDXSong] {
        var result: [String: IIDXSong] = [:]
        let fetchedSongs = fetchAllSongs()
        fetchedSongs.forEach { song in
            result[song.titleCompact()] = song
        }
        return result
    }

    func fetchAllSongs() -> [IIDXSong] {
        guard let database = try? BEMANIWikiDatabase.shared.getReadConnection() else { return [] }
        let query = BEMANIWikiDatabase.songTable.order(BEMANIWikiDatabase.songTitle.asc)
        return (try? database.prepare(query).map { Self.song(from: $0) }) ?? []
    }

    // MARK: BM2DX Notes Radar

    func fetchChartRadarData(title: String, playType: IIDXPlayType, difficulty: Int) -> ChartRadarData? {
        guard let database = try? BM2DXDatabase.shared.getReadConnection() else { return nil }
        let col = BM2DXDatabase.self
        let playTypeString = playType == .single ? "SP" : "DP"
        let query = col.notesRadarTable
            .filter(col.nrTitle == title && col.nrPlayType == playTypeString && col.nrDifficulty == difficulty)
            .limit(1)
        guard let row = try? database.pluck(query) else { return nil }
        return ChartRadarData(
            title: row[col.nrTitle],
            playType: row[col.nrPlayType],
            difficulty: row[col.nrDifficulty],
            noteCount: row[col.nrNoteCount],
            radarData: RadarData(
                notes: row[col.nrNotes],
                chord: row[col.nrChord],
                peak: row[col.nrPeak],
                charge: row[col.nrCharge],
                scratch: row[col.nrScratch],
                soflan: row[col.nrSoflan]
            )
        )
    }

    func fetchAllChartRadarData() -> [ChartRadarData] {
        guard let database = try? BM2DXDatabase.shared.getReadConnection() else { return [] }
        let col = BM2DXDatabase.self
        let query = col.notesRadarTable.order(col.nrTitle.asc)
        return (try? database.prepare(query).map { row in
            ChartRadarData(
                title: row[col.nrTitle],
                playType: row[col.nrPlayType],
                difficulty: row[col.nrDifficulty],
                noteCount: row[col.nrNoteCount],
                radarData: RadarData(
                    notes: row[col.nrNotes],
                    chord: row[col.nrChord],
                    peak: row[col.nrPeak],
                    charge: row[col.nrCharge],
                    scratch: row[col.nrScratch],
                    soflan: row[col.nrSoflan]
                )
            )
        }) ?? []
    }

    func bemaniWikiSongCount() -> Int {
        guard let database = try? BEMANIWikiDatabase.shared.getReadConnection() else { return 0 }
        return (try? database.scalar(BEMANIWikiDatabase.songTable.count)) ?? 0
    }

    func chartRadarDataCount() -> Int {
        guard let database = try? BM2DXDatabase.shared.getReadConnection() else { return 0 }
        return (try? database.scalar(BM2DXDatabase.notesRadarTable.count)) ?? 0
    }

    // MARK: Analytics - Aggregated Counts

    private struct LevelColumns {
        let difficulty: SQLite.Expression<Int>
        let clearType: SQLite.Expression<String>
        let djLevel: SQLite.Expression<String>
        let score: SQLite.Expression<Int>
    }

    func aggregatedCounts(
        for importGroupIDs: [String],
        playType: IIDXPlayType
    ) -> (clearType: [String: [Int: [String: Int]]], djLevel: [String: [Int: [String: Int]]]) {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else {
            return ([:], [:])
        }
        let cols = PlayDataDatabase.self

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

        let idSet = importGroupIDs
        let table = PlayDataDatabase.songRecordTable
            .filter(idSet.contains(cols.srImportGroupID) && cols.srPlayType == playType.rawValue)

        for level in levelColumns {
            let clearQuery = table
                .select(cols.srImportGroupID, level.difficulty, level.clearType, level.score.count)
                .filter(level.difficulty > 0 && level.clearType != "NO PLAY" && level.score > 0)
                .group(cols.srImportGroupID, level.difficulty, level.clearType)

            if let rows = try? database.prepare(clearQuery) {
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

            if let rows = try? database.prepare(djQuery) {
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

    func importGroups(for version: IIDXVersion) -> [ImportGroup] {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.importGroupTable
            .filter(PlayDataDatabase.igIIDXVersion == version.rawValue)
            .order(PlayDataDatabase.igImportDate.asc)
        return (try? database.prepare(query).map { Self.importGroup(from: $0) }) ?? []
    }

    // MARK: Tower Entries

    func allTowerEntries() -> [IIDXTowerEntry] {
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.towerEntryTable.order(PlayDataDatabase.tePlayDate.desc)
        return (try? database.prepare(query).map { Self.towerEntry(from: $0) }) ?? []
    }

    // MARK: Key Paths

    func scoreKeyPath(for level: IIDXLevel) -> KeyPath<IIDXSongRecord, IIDXLevelScore>? {
        switch level {
        case .beginner: return \.beginnerScore
        case .normal: return \.normalScore
        case .hyper: return \.hyperScore
        case .another: return \.anotherScore
        case .leggendaria: return \.leggendariaScore
        default: return nil
        }
    }

    // MARK: Row Mapping

    static func importGroup(from row: Row) -> ImportGroup {
        let group = ImportGroup(
            importDate: Date(timeIntervalSince1970: row[PlayDataDatabase.igImportDate]),
            iidxData: [],
            iidxVersion: row[PlayDataDatabase.igIIDXVersion].flatMap { IIDXVersion(rawValue: $0) } ?? .epolis
        )
        group.id = row[PlayDataDatabase.igID]
        if row[PlayDataDatabase.igIIDXVersion] == nil {
            group.iidxVersion = nil
        }
        return group
    }

    static func songRecord(from row: Row) -> IIDXSongRecord {
        let record = IIDXSongRecord()
        record.version = row[PlayDataDatabase.srVersion]
        record.title = row[PlayDataDatabase.srTitle]
        record.genre = row[PlayDataDatabase.srGenre]
        record.artist = row[PlayDataDatabase.srArtist]
        record.playCount = row[PlayDataDatabase.srPlayCount]
        record.playType = IIDXPlayType(rawValue: row[PlayDataDatabase.srPlayType]) ?? .single
        record.lastPlayDate = Date(timeIntervalSince1970: row[PlayDataDatabase.srLastPlayDate])

        record.beginnerScore = levelScore(from: row, prefix: "beginner")
        record.normalScore = levelScore(from: row, prefix: "normal")
        record.hyperScore = levelScore(from: row, prefix: "hyper")
        record.anotherScore = levelScore(from: row, prefix: "another")
        record.leggendariaScore = levelScore(from: row, prefix: "leggendaria")

        return record
    }

    private static func levelScore(from row: Row, prefix: String) -> IIDXLevelScore {
        let database = PlayDataDatabase.self
        let levelCol: SQLite.Expression<String>
        let diffCol: SQLite.Expression<Int>
        let scoreCol: SQLite.Expression<Int>
        let pgCol: SQLite.Expression<Int>
        let gCol: SQLite.Expression<Int>
        let mCol: SQLite.Expression<Int>
        let ctCol: SQLite.Expression<String>
        let djCol: SQLite.Expression<String>

        switch prefix {
        case "beginner":
            levelCol = database.srBeginnerLevel; diffCol = database.srBeginnerDifficulty
            scoreCol = database.srBeginnerScore; pgCol = database.srBeginnerPerfectGreatCount
            gCol = database.srBeginnerGreatCount; mCol = database.srBeginnerMissCount
            ctCol = database.srBeginnerClearType; djCol = database.srBeginnerDJLevel
        case "normal":
            levelCol = database.srNormalLevel; diffCol = database.srNormalDifficulty
            scoreCol = database.srNormalScore; pgCol = database.srNormalPerfectGreatCount
            gCol = database.srNormalGreatCount; mCol = database.srNormalMissCount
            ctCol = database.srNormalClearType; djCol = database.srNormalDJLevel
        case "hyper":
            levelCol = database.srHyperLevel; diffCol = database.srHyperDifficulty
            scoreCol = database.srHyperScore; pgCol = database.srHyperPerfectGreatCount
            gCol = database.srHyperGreatCount; mCol = database.srHyperMissCount
            ctCol = database.srHyperClearType; djCol = database.srHyperDJLevel
        case "another":
            levelCol = database.srAnotherLevel; diffCol = database.srAnotherDifficulty
            scoreCol = database.srAnotherScore; pgCol = database.srAnotherPerfectGreatCount
            gCol = database.srAnotherGreatCount; mCol = database.srAnotherMissCount
            ctCol = database.srAnotherClearType; djCol = database.srAnotherDJLevel
        default: // leggendaria
            levelCol = database.srLeggendariaLevel; diffCol = database.srLeggendariaDifficulty
            scoreCol = database.srLeggendariaScore; pgCol = database.srLeggendariaPerfectGreatCount
            gCol = database.srLeggendariaGreatCount; mCol = database.srLeggendariaMissCount
            ctCol = database.srLeggendariaClearType; djCol = database.srLeggendariaDJLevel
        }

        return IIDXLevelScore(
            level: IIDXLevel(csvValue: row[levelCol]),
            difficulty: row[diffCol],
            score: row[scoreCol],
            perfectGreatCount: row[pgCol],
            greatCount: row[gCol],
            missCount: row[mCol],
            clearType: row[ctCol],
            djLevel: row[djCol]
        )
    }

    static func song(from row: Row) -> IIDXSong {
        let song = IIDXSong()
        song.title = row[BEMANIWikiDatabase.songTitle]
        song.time = row[BEMANIWikiDatabase.songTime]
        song.movie = row[BEMANIWikiDatabase.songMovie]
        song.layer = row[BEMANIWikiDatabase.songLayer]
        let database = BEMANIWikiDatabase.self
        let spB = row[database.songSPBeginnerNoteCount]
        let spN = row[database.songSPNormalNoteCount]
        let spH = row[database.songSPHyperNoteCount]
        let spA = row[database.songSPAnotherNoteCount]
        let spL = row[database.songSPLeggendariaNoteCount]
        if spB != nil || spN != nil || spH != nil || spA != nil || spL != nil {
            song.spNoteCount = IIDXNoteCount(
                beginnerNoteCount: spB.map(String.init) ?? "-",
                normalNoteCount: spN.map(String.init) ?? "-",
                hyperNoteCount: spH.map(String.init) ?? "-",
                anotherNoteCount: spA.map(String.init) ?? "-",
                leggendariaNoteCount: spL.map(String.init) ?? "-",
                playType: .single
            )
        }
        let dpB = row[database.songDPBeginnerNoteCount]
        let dpN = row[database.songDPNormalNoteCount]
        let dpH = row[database.songDPHyperNoteCount]
        let dpA = row[database.songDPAnotherNoteCount]
        let dpL = row[database.songDPLeggendariaNoteCount]
        if dpB != nil || dpN != nil || dpH != nil || dpA != nil || dpL != nil {
            song.dpNoteCount = IIDXNoteCount(
                beginnerNoteCount: dpB.map(String.init) ?? "-",
                normalNoteCount: dpN.map(String.init) ?? "-",
                hyperNoteCount: dpH.map(String.init) ?? "-",
                anotherNoteCount: dpA.map(String.init) ?? "-",
                leggendariaNoteCount: dpL.map(String.init) ?? "-",
                playType: .double
            )
        }
        return song
    }

    static func towerEntry(from row: Row) -> IIDXTowerEntry {
        IIDXTowerEntry(
            playDate: Date(timeIntervalSince1970: row[PlayDataDatabase.tePlayDate]),
            keyCount: row[PlayDataDatabase.teKeyCount],
            scratchCount: row[PlayDataDatabase.teScratchCount]
        )
    }
}
// swiftlint:enable file_length

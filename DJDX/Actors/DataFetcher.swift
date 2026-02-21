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

            if filters.onlyPlayDataWithScores {
                if filters.level != .all,
                   let keyPath = scoreKeyPath(for: filters.level) {
                        filteredSongRecords.removeAll { songRecord in
                            songRecord[keyPath: keyPath].score == 0
                        }
                }
                if filters.difficulty != .all {
                    filteredSongRecords.removeAll { songRecord in
                        if let score = songRecord.score(for: filters.difficulty) {
                            return score.score == 0
                        }
                        return false
                    }
                }
                filteredSongRecords.removeAll { songRecord in
                    songRecord.beginnerScore.score == 0 &&
                    songRecord.normalScore.score == 0 &&
                    songRecord.hyperScore.score == 0 &&
                    songRecord.anotherScore.score == 0 &&
                    songRecord.leggendariaScore.score == 0
                }
            }

            filteredSongRecords.removeAll { songRecord in

                if filters.difficulty != .all, songRecord.score(for: filters.difficulty) == nil {
                    return true
                }

                if filters.level != .all {
                    if songRecord.score(for: filters.level) == nil {
                        return true
                    } else {
                        if filters.difficulty != .all,
                           songRecord.score(for: filters.level)?.difficulty != filters.difficulty.rawValue {
                            return true
                        }
                    }
                }

                if filters.clearType != .all {
                    let isDifficultyFilterActive = filters.difficulty != .all
                    let isLevelFilterActive = filters.level != .all
                    if isDifficultyFilterActive && !isLevelFilterActive,
                       songRecord.score(for: filters.difficulty)?.clearType != filters.clearType.rawValue {
                        return true
                    } else if isDifficultyFilterActive && isLevelFilterActive,
                              songRecord.score(for: filters.level)?.clearType != filters.clearType.rawValue {
                        return true
                    } else if isDifficultyFilterActive && isLevelFilterActive,
                              songRecord.score(for: filters.difficulty)?.level ==
                                songRecord.score(for: filters.level)?.level,
                              songRecord.score(for: filters.difficulty)?.clearType != filters.clearType.rawValue {
                        return true
                    } else {
                        if !songRecord.scores().contains(where: { $0.clearType == filters.clearType.rawValue }) {
                            return true
                        }
                    }
                }

                return false
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
                if let level = filters?.level,
                   level != .all,
                    let keyPath = scoreKeyPath(for: level) {
                    songLevelScores = sortedSongRecords.reduce(into: [:], { partialResult, songRecord in
                        partialResult[songRecord] = songRecord[keyPath: keyPath]
                    })
                } else if let difficulty = filters?.difficulty,
                          difficulty != .all {
                    songLevelScores = sortedSongRecords.reduce(into: [:], { partialResult, songRecord in
                        partialResult[songRecord] = songRecord.score(for: difficulty)
                    })
                }
            }

            switch sortOptions.mode {
            case .title:
                sortedSongRecords.sort { lhs, rhs in
                    lhs.title < rhs.title
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
                                return lhsIndex < rhsIndex
                            } else {
                                return true
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
                                return lhsIndex > rhsIndex
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
                                        return lhsScoreRate > rhsScoreRate
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
            case .scoreAscending:
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        if lhs.value.score == rhs.value.score {
                            return lhs.key.title < rhs.key.title
                        } else {
                            return lhs.value.score < rhs.value.score
                        }
                    })
                    .map({ $0.key })
            case .scoreDescending:
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        if lhs.value.score == rhs.value.score {
                            return lhs.key.title < rhs.key.title
                        } else {
                            return lhs.value.score > rhs.value.score
                        }
                    })
                    .map({ $0.key })
            case .difficultyAscending:
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        if lhs.value.difficulty == rhs.value.difficulty {
                            return lhs.key.title < rhs.key.title
                        } else {
                            return lhs.value.difficulty < rhs.value.difficulty
                        }
                    })
                    .map({ $0.key })
            case .difficultyDescending:
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        if lhs.value.difficulty == rhs.value.difficulty {
                            return lhs.key.title < rhs.key.title
                        } else {
                            return lhs.value.difficulty > rhs.value.difficulty
                        }
                    })
                    .map({ $0.key })
            case .lastPlayDate:
                sortedSongRecords.sort { lhs, rhs in
                    lhs.lastPlayDate > rhs.lastPlayDate
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
        guard let database = try? PlayDataDatabase.shared.getReadConnection() else { return [] }
        let query = PlayDataDatabase.songTable.order(PlayDataDatabase.songTitle.asc)
        return (try? database.prepare(query).map { Self.song(from: $0) }) ?? []
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
        song.title = row[PlayDataDatabase.songTitle]
        song.time = row[PlayDataDatabase.songTime]
        song.movie = row[PlayDataDatabase.songMovie]
        song.layer = row[PlayDataDatabase.songLayer]
        let database = PlayDataDatabase.self
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

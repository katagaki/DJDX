//
//  DataFetcher.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/05.
//

import Foundation
import SwiftData

@ModelActor
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
        let importGroupsForSelectedDate: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                predicate: importGroups(from: selectedDate),
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        if let importGroupForSelectedDate = importGroupsForSelectedDate.first {
            // Use selected date's import group
            return importGroupForSelectedDate
        } else {
            // Use latest available import group
            let allImportGroups: [ImportGroup] = (try? modelContext.fetch(
                FetchDescriptor<ImportGroup>(
                    sortBy: [SortDescriptor(\.importDate, order: .forward)]
                )
            )) ?? []
            var importGroupClosestToTheSelectedDate: ImportGroup?
            for importGroup in allImportGroups {
                if importGroup.importDate <= selectedDate {
                    importGroupClosestToTheSelectedDate = importGroup
                } else {
                    break
                }
            }
            if let importGroupClosestToTheSelectedDate {
                return importGroupClosestToTheSelectedDate
            }
        }
        return nil
    }

    func importGroupIdentifier(for selectedDate: Date) -> PersistentIdentifier? {
        if let importGroup = importGroup(for: selectedDate) {
            return importGroup.persistentModelID
        }
        return nil
    }

    func importGroupID(for identifier: PersistentIdentifier) -> String? {
        if let importGroup = modelContext.model(for: identifier) as? ImportGroup {
            return importGroup.id
        }
        return nil
    }

    // MARK: Song Records

    func songRecords(for importGroupID: String) -> [PersistentIdentifier] {
        let songRecords: [IIDXSongRecord]? = try? modelContext.fetch(
            FetchDescriptor<IIDXSongRecord>(
                predicate: #Predicate<IIDXSongRecord> {
                    $0.importGroup?.id == importGroupID
                },
                sortBy: [SortDescriptor(\.title, order: .forward)]
            )
        )
        return (songRecords ?? []).map { $0.persistentModelID }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func songRecords(
        on playDataDate: Date,
        filters: FilterOptions?,
        sortOptions: SortOptions?
    ) -> [PersistentIdentifier]? {

        // Get import group for selected date
        guard let importGroup = importGroup(for: playDataDate) else {
            return nil
        }

        if importGroupID != importGroup.id {
            importGroupID = importGroup.id

            // Get new song records in import group
            allSongRecords = (try? modelContext.fetch(
                FetchDescriptor<IIDXSongRecord>(
                    predicate: #Predicate<IIDXSongRecord> {
                        $0.importGroup?.id == importGroupID
                    },
                    sortBy: [SortDescriptor(\.title, order: .forward)]
                )
            )) ?? []

            // TODO: Find a way to trigger a refresh only on wiki data instead of just caching as-is
            if songs.isEmpty {
                songs = (try? modelContext.fetch(
                    FetchDescriptor<IIDXSong>(
                        sortBy: [SortDescriptor(\.title, order: .forward)]
                    )
                )) ?? []
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

            // Filter song records
            filteredSongRecords = allSongRecords.filter({
                $0.playType == filters.playType
            })

            // Filter song records that have no scores
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

                // Filter song records by difficulty
                if filters.difficulty != .all, songRecord.score(for: filters.difficulty) == nil {
                    return true
                }

                // Filter song records by level
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

                // Filter song records by clear type
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
        } else if filters == previousFilters {
            debugPrint("Filters were not changed, using previously filtered song records")
            songRecords = filteredSongRecords
        }

        if filters != previousFilters || sortOptions != previousSortOptions, let sortOptions {
            debugPrint("Filters or sort options were changed, sorting")

            sortedSongRecords = songRecords
            var songLevelScores: [IIDXSongRecord: IIDXLevelScore] = [:]

            // Get the level score to be used for sorting
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

            // Sort dictionary
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
        } else if filters == previousFilters && sortOptions == previousSortOptions {
            debugPrint("Filters or sort options were not changed, using previously sorted song records")
            songRecords = sortedSongRecords
        }

        previousFilters = filters
        previousSortOptions = sortOptions
        return songRecords.map { $0.persistentModelID }
    }

    // MARK: Song Metadata

//    func songNoteCounts() -> [String: IIDXNoteCount] {
//        let songs = try? modelContext.fetch(
//            FetchDescriptor<IIDXSong>(
//                sortBy: [SortDescriptor(\.title, order: .forward)]
//            )
//        )
//        let songMappings = (songs ?? [])
//            .reduce(into: [:]) { partialResult, song in
//                partialResult[song.titleCompact()] = song.spNoteCount
//            }
//        return songMappings
//    }

    func songCompactTitles() -> [String: PersistentIdentifier] {
        var songCompactTitles: [String: PersistentIdentifier] = [:]
        let songs = (try? modelContext.fetch(
            FetchDescriptor<IIDXSong>(
                sortBy: [SortDescriptor(\.title, order: .forward)]
            )
        )) ?? []
        songs.forEach { song in
            songCompactTitles[song.titleCompact()] = song.persistentModelID
        }
        return songCompactTitles
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
}

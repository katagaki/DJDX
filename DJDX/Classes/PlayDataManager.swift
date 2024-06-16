//
//  PlayDataManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/06.
//

import Foundation
import SwiftData
import SwiftUI

// swiftlint:disable type_body_length
class PlayDataManager: ObservableObject {

    // Global Filters
    @Published var playType: IIDXPlayType = .single

    // External Data
    @Published var allSongs: [IIDXSong]
    var allSongCompactTitles: [String: IIDXSong] = [:]

    // Play Data Cache
    var allSongRecords: [IIDXSongRecord] = []
    var allSongRecordLevelMaps: [IIDXSongRecord: IIDXLevelScore] = [:] // TODO: Implement show scores separately feature
    var allSongNoteCounts: [String: IIDXNoteCount] = [:]
    var filteredSongRecords: [IIDXSongRecord] = []
    var sortedSongRecords: [IIDXSongRecord] = []

    // Presentation Data
    @Published var displayedSongRecords: [IIDXSongRecord] = []
    @Published var displayedSongRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = [:]

    // MARK: Master Data Functions

    init() {
        let modelContext = ModelContext(sharedModelContainer)
        allSongs = (try? modelContext.fetch(
            FetchDescriptor<IIDXSong>(
                sortBy: [SortDescriptor(\.title, order: .forward)]
            )
        )) ?? []
        allSongs.forEach { song in
            allSongCompactTitles[song.titleCompact()] = song
        }
    }

    func reloadAllSongs() async {
        let modelContext = ModelContext(sharedModelContainer)
        let allSongs = (try? modelContext.fetch(
            FetchDescriptor<IIDXSong>(
                sortBy: [SortDescriptor(\.title, order: .forward)]
            )
        )) ?? []
        allSongs.forEach { song in
            allSongCompactTitles[song.titleCompact()] = song
        }
        await MainActor.run { [allSongs] in
            withAnimation(.snappy.speed(2.0)) {
                self.allSongs = allSongs
            }
        }
    }

    func reloadAllSongRecords(in calendar: CalendarManager) async {
        debugPrint("Removing all song records")
        await MainActor.run {
            withAnimation(.snappy.speed(2.0)) {
                displayedSongRecords.removeAll()
                displayedSongRecordClearRates.removeAll()
            }
        }
        sortedSongRecords.removeAll()
        filteredSongRecords.removeAll()
        allSongRecords.removeAll()
        allSongNoteCounts.removeAll()

        debugPrint("Performing required data migration (if any)")
        await migrateDataToNewerSchema()

        debugPrint("Loading new song records")
        let modelContext = ModelContext(sharedModelContainer)
        let newSongRecords = calendar.latestAvailableIIDXSongRecords(
            in: modelContext
        )
            .filter({$0.playType == playType})
        let newSongMappings = ((try? modelContext.fetch(FetchDescriptor<IIDXSong>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        ))) ?? [])
            .reduce(into: [:]) { partialResult, song in
                partialResult[song.titleCompact()] = song.spNoteCount
            }

        allSongRecords = newSongRecords
        allSongNoteCounts = newSongMappings
    }

    func filterSongRecords(playTypeToShow: IIDXPlayType,
                           isShowingOnlyPlayDataWithScores: Bool,
                           levelToShow: IIDXLevel,
                           difficultyToShow: IIDXDifficulty) async {
        debugPrint("Filtering song records")
        var filteredSongRecords: [IIDXSongRecord] = self.allSongRecords

        // Filter songs by play type
        filteredSongRecords.removeAll(where: { songRecord in
            songRecord.playType != playTypeToShow
        })

        // Remove song records that have no scores
        if isShowingOnlyPlayDataWithScores {
            if let keyPath = scoreKeyPath(for: levelToShow) {
                filteredSongRecords.removeAll { songRecord in
                    songRecord[keyPath: keyPath].score == 0
                }
            } else {
                filteredSongRecords.removeAll { songRecord in
                    songRecord.beginnerScore.score == 0 &&
                    songRecord.normalScore.score == 0 &&
                    songRecord.hyperScore.score == 0 &&
                    songRecord.anotherScore.score == 0 &&
                    songRecord.leggendariaScore.score == 0
                }
            }
        }

        // Filter song records by level
        if let keyPath = scoreKeyPath(for: levelToShow) {
            filteredSongRecords.removeAll { songRecord in
                songRecord[keyPath: keyPath].difficulty == 0
            }
        }

        // Filter song records by level
        if difficultyToShow != .all {
            filteredSongRecords.removeAll { songRecord in
                songRecord.score(for: difficultyToShow) == nil
            }
        }

        self.filteredSongRecords = filteredSongRecords
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    func sortSongRecords(sortMode: SortMode,
                         levelToShow: IIDXLevel,
                         difficultyToShow: IIDXDifficulty) async {
        debugPrint("Sorting song records")
        var sortedSongRecords: [IIDXSongRecord] = self.filteredSongRecords
        var songLevelScores: [IIDXSongRecord: IIDXLevelScore] = [:]

        // Get the level score to be used for sorting
        if sortMode != .title && sortMode != .lastPlayDate {
            if levelToShow != .all, let keyPath = scoreKeyPath(for: levelToShow) {
                songLevelScores = sortedSongRecords.reduce(into: [:], { partialResult, songRecord in
                    partialResult[songRecord] = songRecord[keyPath: keyPath]
                })
            } else if difficultyToShow != .all {
                songLevelScores = sortedSongRecords.reduce(into: [:], { partialResult, songRecord in
                    partialResult[songRecord] = songRecord.score(for: difficultyToShow)
                })
            }
        }

        // Sort dictionary
        switch sortMode {
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
            if allSongNoteCounts.count > 0 {
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        let lhsSong = allSongNoteCounts[lhs.key.titleCompact()]
                        let rhsSong = allSongNoteCounts[rhs.key.titleCompact()]
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

        self.sortedSongRecords = sortedSongRecords
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    func searchSongRecords(searchTerm: String) async {
        debugPrint("Searching song records")
        let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
        var displayedSongRecords: [IIDXSongRecord] = []
        var displayedSongRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = [:]
        if !searchTermTrimmed.isEmpty && searchTermTrimmed.count >= 1 {
            displayedSongRecords = self.sortedSongRecords.filter({ songRecord in
                songRecord.title.lowercased().contains(searchTermTrimmed) ||
                songRecord.artist.lowercased().contains(searchTermTrimmed)
            })
        } else {
            displayedSongRecords = self.sortedSongRecords
            displayedSongRecordClearRates = self.sortedSongRecords
                .reduce(into: [:], { partialResult, songRecord in
                    let song = allSongNoteCounts[songRecord.titleCompact()]
                    if let song {
                        var scores: [IIDXLevelScore] = [
                            songRecord.beginnerScore,
                            songRecord.normalScore,
                            songRecord.hyperScore,
                            songRecord.anotherScore,
                            songRecord.leggendariaScore
                        ]
                        scores.removeAll(where: { $0.score == 0 })
                        let scoreRates = scores.reduce(into: [:] as [IIDXLevel: Float]) { partialResult, score in
                            if let noteCount = song.noteCount(for: score.level) {
                                partialResult[score.level] = Float(score.score) / Float(noteCount * 2)
                            }
                        }
                        partialResult[songRecord] = scoreRates
                    }
            })
        }
        await MainActor.run { [displayedSongRecords, displayedSongRecordClearRates] in
            withAnimation(.snappy.speed(2.0)) {
                self.displayedSongRecords = displayedSongRecords
                self.displayedSongRecordClearRates = displayedSongRecordClearRates
            }
        }
    }

    func cleanUpOrphanedSongRecords() async {
        debugPrint("Cleaning up orphaned song records")
        let modelContext = ModelContext(sharedModelContainer)
        let songRecords = (try? modelContext.fetch(FetchDescriptor<IIDXSongRecord>(
            predicate: #Predicate<IIDXSongRecord> {
                $0.importGroup == nil
            }))) ?? []
        for songRecord in songRecords {
            modelContext.delete(songRecord)
        }
        try? modelContext.save()
    }

    func migrateDataToNewerSchema() async {
        let defaults = UserDefaults.standard
        let dataMigrationKeys = ["Internal.DataMigrationForBetaBuild84"]

        for dataMigrationKey in dataMigrationKeys {
            switch dataMigrationKey {
            case "Internal.DataMigrationForBetaBuild84":
                if !defaults.bool(forKey: dataMigrationKey) {
                    debugPrint("Performing migration when migrating from 1.0-84 to 1.0-85+")
                    UserDefaults.standard.set(true, forKey: dataMigrationKey)
                    let modelContext = ModelContext(sharedModelContainer)
                    let songRecords = try? modelContext.fetch(FetchDescriptor<IIDXSongRecord>())
                    for songRecord in songRecords ?? [] {
                        songRecord.playType = .single
                    }
                    try? modelContext.save()
                }
            default: break
            }
        }
    }

    // MARK: Convenience Functions

    func scoreRate(for songRecord: IIDXSongRecord, of level: IIDXLevel, or difficulty: IIDXDifficulty) -> Float? {
        return displayedSongRecordClearRates[songRecord]?[
            songRecord.level(for: level, or: difficulty)]
    }

    func noteCount(for songRecord: IIDXSongRecord, of level: IIDXLevel) -> Int? {
        let compactTitle = songRecord.titleCompact()
        if let keyPath = noteCountKeyPath(for: level) {
            return allSongCompactTitles[compactTitle]?.spNoteCount?[keyPath: keyPath]
        } else {
            return nil
        }
    }

    func noteCountKeyPath(for level: IIDXLevel) -> KeyPath<IIDXNoteCount, Int?>? {
        switch level {
        case .beginner: return \.beginnerNoteCount
        case .normal: return \.normalNoteCount
        case .hyper: return \.hyperNoteCount
        case .another: return \.anotherNoteCount
        case .leggendaria: return \.leggendariaNoteCount
        default: return nil
        }
    }

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
// swiftlint:enable type_body_length

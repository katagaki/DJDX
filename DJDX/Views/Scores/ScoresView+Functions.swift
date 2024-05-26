//
//  ScoresView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/26.
//

import Foundation
import SwiftData
import SwiftUI

extension ScoresView {
    func reloadAllScores() {
        allSongRecords = ScoresView
            .latestAvailableIIDXSongRecords(in: ModelContext(sharedModelContainer), using: calendar)
    }

    func reloadDisplayedScores() {
        withAnimation(.snappy.speed(2.0)) {
            dataState = .loading
        }
        let filteredSongRecords = filterSongRecords(allSongRecords)
        let searchedSongRecords = searchSongRecords(filteredSongRecords, searchTerm: searchTerm)
        let sortedSongRecords = sortSongRecords(searchedSongRecords)
        withAnimation(.snappy.speed(2.0)) {
            songRecords = filteredSongRecords
            displayedSongRecords = sortedSongRecords
            dataState = .presenting
        }
    }

    func searchSongRecords(_ songRecords: [IIDXSongRecord], searchTerm: String) -> [IIDXSongRecord] {
        let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
        if !searchTermTrimmed.isEmpty && searchTermTrimmed.count >= 2 {
            return songRecords.filter({ songRecord in
                return songRecord.title.lowercased().contains(searchTermTrimmed) ||
                songRecord.artist.lowercased().contains(searchTermTrimmed)
            })
        } else {
            return songRecords
        }
    }

    func filterSongRecords(_ songRecords: [IIDXSongRecord]) -> [IIDXSongRecord] {
        var filteredSongRecords: [IIDXSongRecord] = songRecords

        // Filter by search term
        filteredSongRecords = searchSongRecords(filteredSongRecords, searchTerm: searchTerm)

        // Filter song records
        if let keyPath = keyPath(for: levelToShow) {
            filteredSongRecords.removeAll { songRecord in
                songRecord[keyPath: keyPath].difficulty == 0 ||
                (isShowingOnlyPlayDataWithScores && songRecord[keyPath: keyPath].score == 0)
            }
        }

        // Sort song records
        if sortMode != .title {
            filteredSongRecords = sortSongRecords(filteredSongRecords)
        }

        return filteredSongRecords
    }

    func sortSongRecords(_ songRecords: [IIDXSongRecord]) -> [IIDXSongRecord] {
        var sortedSongRecords: [IIDXSongRecord] = songRecords
        if let keyPath = keyPath(for: levelToShow) {
            switch sortMode {
            case .title:
                sortedSongRecords.sort { lhs, rhs in
                    lhs.title < rhs.title
                }
            case .clearType:
                sortedSongRecords.sort { lhs, rhs in
                    return clearTypes.firstIndex(of: lhs[keyPath: keyPath].clearType) ?? 0 <
                        clearTypes.firstIndex(of: rhs[keyPath: keyPath].clearType) ?? 1
                }
            case .difficultyAscending:
                sortedSongRecords.sort { lhs, rhs in
                    lhs[keyPath: keyPath].difficulty < rhs[keyPath: keyPath].difficulty
                }
            case .difficultyDescending:
                sortedSongRecords.sort { lhs, rhs in
                    lhs[keyPath: keyPath].difficulty > rhs[keyPath: keyPath].difficulty
                }
            case .lastPlayDate:
                sortedSongRecords.sort { lhs, rhs in
                    return lhs.lastPlayDate > rhs.lastPlayDate
                }
            }
        }
        return sortedSongRecords
    }

    func score(for songRecord: IIDXSongRecord) -> IIDXLevelScore? {
        switch levelToShow {
        case .beginner: return songRecord.beginnerScore
        case .normal: return songRecord.normalScore
        case .hyper: return songRecord.hyperScore
        case .another: return songRecord.anotherScore
        case .leggendaria: return songRecord.leggendariaScore
        default: return nil
        }
    }

    func keyPath(for level: IIDXLevel) -> KeyPath<IIDXSongRecord, IIDXLevelScore>? {
        switch levelToShow {
        case .beginner: return \.beginnerScore
        case .normal: return \.normalScore
        case .hyper: return \.hyperScore
        case .another: return \.anotherScore
        case .leggendaria: return \.leggendariaScore
        default: return nil
        }
    }

    static func latestAvailableIIDXSongRecords(in modelContext: ModelContext,
                                               using calendar: CalendarManager) -> [IIDXSongRecord] {
        let importGroupsForSelectedDate: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                predicate: importGroups(in: calendar),
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        var importGroupID: String?
        if let importGroupForSelectedDate = importGroupsForSelectedDate.first {
            // Use selected date's import group
            importGroupID = importGroupForSelectedDate.id
        } else {
            // Use latest available import group
            let allImportGroups: [ImportGroup] = (try? modelContext.fetch(
                FetchDescriptor<ImportGroup>(
                    sortBy: [SortDescriptor(\.importDate, order: .forward)]
                )
            )) ?? []
            var importGroupClosestToTheSelectedDate: ImportGroup?
            for importGroup in allImportGroups {
                if importGroup.importDate <= calendar.selectedDate {
                    importGroupClosestToTheSelectedDate = importGroup
                } else {
                    break
                }
            }
            if let importGroupClosestToTheSelectedDate {
                importGroupID = importGroupClosestToTheSelectedDate.id
            }
        }
        if let importGroupID {
            let songRecordsInImportGroup: [IIDXSongRecord] = (try? modelContext.fetch(
                FetchDescriptor<IIDXSongRecord>(
                    predicate: iidxSongRecords(inImportGroupWithID: importGroupID),
                    sortBy: [SortDescriptor(\.title, order: .forward)]
                )
            )) ?? []
            return songRecordsInImportGroup
        }
        return []
    }
}

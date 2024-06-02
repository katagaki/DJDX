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

    func filterSongRecords() {
        var filteredSongRecords: [IIDXSongRecord] = self.allSongRecords

        // Remove song records that have no scores
        if isShowingOnlyPlayDataWithScores {
            if let keyPath = keyPath(for: levelToShow) {
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
        if let keyPath = keyPath(for: levelToShow) {
            filteredSongRecords.removeAll { songRecord in
                songRecord[keyPath: keyPath].difficulty == 0
            }
        }

        self.filteredSongRecords = filteredSongRecords
    }

    func sortSongRecords() {
        var sortedSongRecords: [IIDXSongRecord] = self.filteredSongRecords
        if let keyPath = keyPath(for: levelToShow) {
            switch sortMode {
            case .title:
                sortedSongRecords.sort { lhs, rhs in
                    lhs.title < rhs.title
                }
            case .clearType:
                let clearTypes = IIDXClearType.sortedStrings
                sortedSongRecords.sort { lhs, rhs in
                    clearTypes.firstIndex(of: lhs[keyPath: keyPath].clearType) ?? 0 <
                        clearTypes.firstIndex(of: rhs[keyPath: keyPath].clearType) ?? 1
                }
            case .djLevel:
                let djLevels = IIDXDJLevel.sorted
                sortedSongRecords.sort { lhs, rhs in
                    djLevels.firstIndex(of: lhs[keyPath: keyPath].djLevelEnum()) ?? 1 >
                        djLevels.firstIndex(of: rhs[keyPath: keyPath].djLevelEnum()) ?? 0
                }
            case .scoreAscending:
                sortedSongRecords.sort { lhs, rhs in
                    lhs[keyPath: keyPath].score < rhs[keyPath: keyPath].score
                }
            case .scoreDescending:
                sortedSongRecords.sort { lhs, rhs in
                    lhs[keyPath: keyPath].score > rhs[keyPath: keyPath].score
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
                    lhs.lastPlayDate > rhs.lastPlayDate
                }
            }
        }
        self.sortedSongRecords = sortedSongRecords
    }

    func searchSongRecords() {
        let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
        withAnimation(.snappy.speed(2.0)) {
            if !searchTermTrimmed.isEmpty && searchTermTrimmed.count >= 1 {
                self.displayedSongRecords = self.sortedSongRecords.filter({ songRecord in
                    songRecord.title.lowercased().contains(searchTermTrimmed) ||
                    songRecord.artist.lowercased().contains(searchTermTrimmed)
                })
            } else {
                self.displayedSongRecords = self.sortedSongRecords
            }
            dataState = .presenting
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

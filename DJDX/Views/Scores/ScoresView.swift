//
//  ScoresView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import SwiftUI
import SwiftData

struct ScoresView: View {

    @Environment(\.modelContext) var modelContext

    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var calendar: CalendarManager

    @State var allSongRecords: [IIDXSongRecord] = []
    @State var filteredSongRecords: [IIDXSongRecord] = []
    @State var sortedSongRecords: [IIDXSongRecord] = []
    @State var displayedSongRecords: [IIDXSongRecord] = []
    @State var dataState: DataState = .initializing

    @AppStorage(wrappedValue: true, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: .all, "ScoresView.LevelFilter") var levelToShow: IIDXLevel
    @AppStorage(wrappedValue: .all, "ScoresView.DifficultyFilter") var difficultyToShow: IIDXDifficulty

    @AppStorage(wrappedValue: .title, "ScoresView.SortOrder") var sortMode: SortMode

    @State var searchTerm: String = ""
    @State var isSystemChangingFilterAndSort: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach(displayedSongRecords, id: \.title) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        ScoreRow(
                            songRecord: songRecord,
                            levelToShow: $levelToShow,
                            difficultyToShow: $difficultyToShow
                        )
                    }
                    .listRowInsets(.init(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 20.0))
                }
            }
            .navigationTitle("ViewTitle.Scores")
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ScoreSortAndFilter(isShowingOnlyPlayDataWithScores: $isShowingOnlyPlayDataWithScores,
                                       levelToShow: $levelToShow,
                                       difficultyToShow: $difficultyToShow,
                                       sortMode: $sortMode,
                                       isSystemChangingFilterAndSort: $isSystemChangingFilterAndSort) {
                        filterSongRecords()
                    }
                }
            }
            .overlay {
                switch dataState {
                case .initializing, .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                case .presenting:
                    if allSongRecords.count == 0 {
                        ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
                    } else {
                        Color.clear
                    }
                }
            }
            .task {
                if dataState == .initializing {
                    reloadAllSongRecords()
                }
            }
            .searchable(text: $searchTerm,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Scores.Search.Prompt")
            .refreshable {
                reloadAllSongRecords()
            }
            .onChange(of: isShowingOnlyPlayDataWithScores) { _, _ in
                filterSongRecords()
            }
            .onChange(of: allSongRecords) { _, _ in
                debugPrint("Filtering song records after all song records changed")
                filterSongRecords()
            }
            .onChange(of: levelToShow) { _, newValue in
                if !isSystemChangingFilterAndSort && newValue != .all {
                    debugPrint("Filtering song records after level filter changed")
                    difficultyToShow = .all
                    filterSongRecords()
                }
            }
            .onChange(of: difficultyToShow) { _, newValue in
                if !isSystemChangingFilterAndSort && newValue != .all {
                    debugPrint("Filtering song records after difficulty filter changed")
                    levelToShow = .all
                    if sortMode == .difficultyAscending || sortMode == .difficultyDescending {
                        isSystemChangingFilterAndSort = true
                        sortMode = .title
                        isSystemChangingFilterAndSort = false
                    }
                    filterSongRecords()
                }
            }
            .onChange(of: filteredSongRecords) { _, _ in
                debugPrint("Sorting song records after filtered song records changed")
                sortSongRecords()
            }
            .onChange(of: sortMode) { _, _ in
                if !isSystemChangingFilterAndSort {
                    debugPrint("Sorting song records after sort mode changed")
                    sortSongRecords()
                }
            }
            .onChange(of: sortedSongRecords) { _, _ in
                debugPrint("Searching song records after sorted song records changed")
                searchSongRecords()
            }
            .onChange(of: searchTerm) { _, _ in
                debugPrint("Searching song records after search term changed")
                searchSongRecords()
            }
            .onChange(of: calendar.selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    dataState = .initializing
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord):
                    ScoreViewer(songRecord: songRecord)
                case .textageViewer(let songTitle, let level, let playSide):
                    TextageViewer(songTitle: songTitle, level: level, playSide: playSide)
                default: Color.clear
                }
            }
        }
    }
}

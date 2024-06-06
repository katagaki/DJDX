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
    @EnvironmentObject var playData: PlayDataManager

    @State var dataState: DataState = .initializing

    @AppStorage(wrappedValue: true, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: .all, "ScoresView.LevelFilter") var levelToShow: IIDXLevel
    @AppStorage(wrappedValue: .all, "ScoresView.DifficultyFilter") var difficultyToShow: IIDXDifficulty

    @AppStorage(wrappedValue: .title, "ScoresView.SortOrder") var sortMode: SortMode

    @State var searchTerm: String = ""
    @State var isSystemChangingFilterAndSort: Bool = false
    @State var isSystemChangingAllRecords: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach(playData.displayedSongRecords, id: \.title) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        ScoreRow(
                            songRecord: songRecord,
                            scoreRate: playData.scoreRate(for: songRecord, of: levelToShow, or: difficultyToShow),
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
                        reloadDisplay(shouldReloadAll: false, shouldFilter: true,
                                      shouldSort: true, shouldSearch: true)
                    }
                }
            }
            .overlay {
                switch dataState {
                case .initializing, .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                case .presenting:
                    if playData.allSongRecords.count == 0 {
                        ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
                    } else {
                        Color.clear
                    }
                }
            }
            .searchable(text: $searchTerm,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Scores.Search.Prompt")
            .refreshable {
                reloadDisplay(shouldReloadAll: true, shouldFilter: true,
                              shouldSort: true, shouldSearch: true)
            }
            .onAppear {
                if dataState == .initializing {
                    debugPrint("Initializing")
                    reloadDisplay(shouldReloadAll: true, shouldFilter: true,
                                  shouldSort: true, shouldSearch: true)
                }
            }
            .onChange(of: isShowingOnlyPlayDataWithScores) { _, _ in
                reloadDisplay(shouldReloadAll: false, shouldFilter: true,
                              shouldSort: true, shouldSearch: true)
            }
            .onChange(of: levelToShow) { _, newValue in
                if !isSystemChangingFilterAndSort && newValue != .all {
                    debugPrint("Filtering song records after level filter changed")
                    difficultyToShow = .all
                    reloadDisplay(shouldReloadAll: false, shouldFilter: true,
                                  shouldSort: true, shouldSearch: true)
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
                    reloadDisplay(shouldReloadAll: false, shouldFilter: true,
                                  shouldSort: true, shouldSearch: true)
                }
            }
            .onChange(of: sortMode) { _, _ in
                if !isSystemChangingFilterAndSort {
                    debugPrint("Sorting song records after sort mode changed")
                    reloadDisplay(shouldReloadAll: false, shouldFilter: false,
                                  shouldSort: true, shouldSearch: true)
                }
            }
            .onChange(of: searchTerm) { _, _ in
                debugPrint("Searching song records after search term changed")
                reloadDisplay(shouldReloadAll: false, shouldFilter: false,
                              shouldSort: false, shouldSearch: true)
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
                case .scoreHistory(let songTitle, let level, let noteCount):
                    ScoreHistoryViewer(songTitle: songTitle,
                                       level: level,
                                       noteCount: noteCount)
                case .textageViewer(let songTitle, let level, let playSide):
                    TextageViewer(songTitle: songTitle, level: level, playSide: playSide)
                default: Color.clear
                }
            }
        }
    }

    @MainActor
    func reloadDisplay(shouldReloadAll: Bool = false,
                       shouldFilter: Bool = false,
                       shouldSort: Bool = false,
                       shouldSearch: Bool = false) {
        Task.detached {
            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    dataState = .loading
                }
            }
            if shouldReloadAll {
                await playData.reloadAllSongRecords(in: calendar)
            }
            if shouldFilter {
                await playData.filterSongRecords(
                    isShowingOnlyPlayDataWithScores: isShowingOnlyPlayDataWithScores,
                    levelToShow: levelToShow,
                    difficultyToShow: difficultyToShow
                )
            }
            if shouldSort {
                await playData.sortSongRecords(
                    sortMode: sortMode,
                    levelToShow: levelToShow,
                    difficultyToShow: difficultyToShow
                )
            }
            if shouldSearch {
                await playData.searchSongRecords(
                    searchTerm: searchTerm
                )
            }
            await MainActor.run {
                withAnimation(.snappy.speed(2.0)) {
                    dataState = .presenting
                }
            }
        }
    }
}

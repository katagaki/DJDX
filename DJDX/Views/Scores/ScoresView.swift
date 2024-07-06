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

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: true, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: .all, "ScoresView.DifficultyFilter") var difficultyToShow: IIDXDifficulty
    @AppStorage(wrappedValue: .all, "ScoresView.LevelFilter") var levelToShow: IIDXLevel
    @AppStorage(wrappedValue: .all, "ScoresView.ClearTypeFilter") var clearTypeToShow: IIDXClearType

    @AppStorage(wrappedValue: .title, "ScoresView.SortOrder") var sortMode: SortMode

    @State var searchTerm: String = ""
    @State var isSystemChangingFilterAndSort: Bool = false
    @State var isSystemChangingAllRecords: Bool = false

    var filters: [String] {
        [String(difficultyToShow.rawValue), levelToShow.rawValue, clearTypeToShow.rawValue]
    }

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
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.plain)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Spacer()
                }
                ToolbarItem(placement: .topBarLeading) {
                    LargeInlineTitle("ViewTitle.Scores")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if dataState == .initializing || dataState == .loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0.0) {
                TabBarAccessory(placement: .bottom) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8.0) {
                            PlayTypePicker(playTypeToShow: $playTypeToShow)
                            ScoreSortAndFilter(isShowingOnlyPlayDataWithScores: $isShowingOnlyPlayDataWithScores,
                                               difficultyToShow: $difficultyToShow,
                                               levelToShow: $levelToShow,
                                               clearTypeToShow: $clearTypeToShow,
                                               sortMode: $sortMode,
                                               isSystemChangingFilterAndSort: $isSystemChangingFilterAndSort) {
                                reloadDisplay(shouldReloadAll: false, shouldFilter: true,
                                              shouldSort: true, shouldSearch: true)
                            }
                        }
                        .padding([.leading, .trailing], 16.0)
                        .padding([.top, .bottom], 12.0)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .overlay {
                switch dataState {
                case .presenting:
                    if playData.allSongRecords.count == 0 {
                        ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
                    } else {
                        Color.clear
                    }
                default: Color.clear
                }
            }
            .searchable(text: $searchTerm,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Scores.Search.Prompt")
            .onAppear {
                if dataState == .initializing {
                    reloadDisplay(shouldReloadAll: true, shouldFilter: true,
                                  shouldSort: true, shouldSearch: true)
                }
            }
            .onChange(of: playTypeToShow) { _, _ in
                if navigationManager.selectedTab == .scores {
                    reloadDisplay(shouldReloadAll: false, shouldFilter: true,
                                  shouldSort: true, shouldSearch: true)
                } else {
                    dataState = .initializing
                }
            }
            .onChange(of: isShowingOnlyPlayDataWithScores) { _, _ in
                reloadDisplay(shouldReloadAll: false, shouldFilter: true,
                              shouldSort: true, shouldSearch: true)
            }
            .onChange(of: filters) {_, _ in
                if !isSystemChangingFilterAndSort {
                    reloadDisplay(shouldReloadAll: false, shouldFilter: true,
                                  shouldSort: true, shouldSearch: true)
                }
            }
            .onChange(of: sortMode) { _, _ in
                if !isSystemChangingFilterAndSort {
                    reloadDisplay(shouldReloadAll: false, shouldFilter: false,
                                  shouldSort: true, shouldSearch: true)
                }
            }
            .onChange(of: searchTerm) { _, _ in
                reloadDisplay(shouldReloadAll: false, shouldFilter: false,
                              shouldSort: false, shouldSearch: true)
            }
            .onChange(of: calendar.didUserPerformChangesRequiringDisplayDataReload, { oldValue, newValue in
                if !oldValue && newValue {
                    calendar.didUserPerformChangesRequiringDisplayDataReload = false
                    dataState = .initializing
                }
            })
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
                case .textageViewer(let songTitle, let level, let playSide, let playType):
                    TextageViewer(songTitle: songTitle, level: level, playSide: playSide, playType: playType)
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
                    playTypeToShow: playTypeToShow,
                    isShowingOnlyPlayDataWithScores: isShowingOnlyPlayDataWithScores,
                    levelToShow: levelToShow,
                    difficultyToShow: difficultyToShow,
                    clearTypeToShow: clearTypeToShow
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

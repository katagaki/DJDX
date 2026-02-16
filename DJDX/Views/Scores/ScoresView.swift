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

    @State var dataState: DataState = .initializing

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: true, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: .all, "ScoresView.DifficultyFilter") var difficultyToShow: IIDXDifficulty
    @AppStorage(wrappedValue: .all, "ScoresView.LevelFilter") var levelToShow: IIDXLevel
    @AppStorage(wrappedValue: .all, "ScoresView.ClearTypeFilter") var clearTypeToShow: IIDXClearType
    @AppStorage(wrappedValue: .title, "ScoresView.SortOrder") var sortMode: SortMode

    @State var playDataDate: Date = .now

    @State var songRecords: [IIDXSongRecord]?
    @State var songRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = [:]

    @State var songCompactTitles: [String: PersistentIdentifier] = [:]
    @State var songNoteCounts: [String: IIDXNoteCount] = [:]

    @State var searchTerm: String = ""
    @State var searchResults: [IIDXSongRecord]?

    @State var isSystemChangingFilterAndSort: Bool = false
    @State var isSystemChangingCalendarDate: Bool = false
    @State var isSystemChangingAllRecords: Bool = false

    var isTimeTravellingKey: String = "ScoresView.IsTimeTravelling"
    @State var isTimeTravelling: Bool

    let actor = DataFetcher(modelContainer: sharedModelContainer)

    @Namespace var scoresNamespace

    var conditionsForReload: [String] {
        [isShowingOnlyPlayDataWithScores.description,
         String(difficultyToShow.rawValue),
         levelToShow.rawValue,
         clearTypeToShow.rawValue,
         sortMode.rawValue]
    }

    init() {
        self.isTimeTravelling = UserDefaults.standard.bool(forKey: isTimeTravellingKey)
    }

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach((searchResults != nil ? searchResults ?? [] : songRecords ?? []),
                        id: \.title) { songRecord in
                    Button {
                        navigationManager.push(.scoreViewer(songRecord: songRecord), for: .scores)
                    } label: {
                        ScoreRow(
                            namespace: scoresNamespace,
                            songRecord: songRecord,
                            scoreRate: scoreRate(for: songRecord, of: levelToShow, or: difficultyToShow),
                            levelToShow: $levelToShow,
                            difficultyToShow: $difficultyToShow
                        )
                    }
                    .listRowInsets(.init(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0))
                    .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                        dimensions[.leading]
                    }
                }
            }
            .navigator("ViewTitle.Scores")
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu(playTypeToShow.displayName()) {
                            Picker("Shared.PlayType", selection: $playTypeToShow) {
                                Text(verbatim: "SP")
                                    .tag(IIDXPlayType.single)
                                Text(verbatim: "DP")
                                    .tag(IIDXPlayType.double)
                            }
                            .pickerStyle(.inline)
                        }
                    }
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
                    VStack(spacing: 8.0) {
                        if isTimeTravelling {
                            DatePicker("Shared.SelectDate",
                                       selection: $playDataDate.animation(.snappy.speed(2.0)),
                                       in: ...Date.now,
                                       displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding([.leading, .trailing], 16.0)
                            .padding([.top], 12.0)
                        }
                        ScrollView(.horizontal) {
                            HStack(spacing: 8.0) {
                                if #unavailable(iOS 26.0) {
                                    PlayTypePicker(playTypeToShow: $playTypeToShow)
                                }
                                ScoreSortAndFilter(isShowingOnlyPlayDataWithScores: $isShowingOnlyPlayDataWithScores,
                                                   difficultyToShow: $difficultyToShow.animation(.snappy.speed(2.0)),
                                                   levelToShow: $levelToShow.animation(.snappy.speed(2.0)),
                                                   clearTypeToShow: $clearTypeToShow.animation(.snappy.speed(2.0)),
                                                   sortMode: $sortMode.animation(.snappy.speed(2.0)),
                                                   isSystemChangingFilterAndSort: $isSystemChangingFilterAndSort) {
                                    reloadDisplay()
                                }
                                ToolbarButton("Shared.ShowPastData", icon: "arrowshape.turn.up.backward.badge.clock",
                                              isSecondary: !isTimeTravelling) {
                                    withAnimation {
                                        isTimeTravelling.toggle()
                                    }
                                    if !isTimeTravelling {
                                        playDataDate = .now
                                    }
                                }
                            }
                            .padding([.leading, .trailing], 16.0)
                            .padding([.top, .bottom], 12.0)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .background {
                switch dataState {
                case .presenting:
                    if songRecords == nil || (searchResults != nil && (searchResults?.isEmpty ?? false)) {
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
            .refreshable {
                reloadDisplay()
            }
            .onAppear {
                if dataState == .initializing {
                    if !isTimeTravelling {
                        isSystemChangingCalendarDate = true
                        playDataDate = .now
                        isSystemChangingCalendarDate = false
                    }
                    reloadDisplay()
                }
            }
            .onChange(of: playTypeToShow) { _, _ in
                if navigationManager.selectedTab == .scores {
                    reloadDisplay()
                } else {
                    dataState = .initializing
                }
            }
            .onChange(of: conditionsForReload) {_, _ in
                if !isSystemChangingFilterAndSort {
                    reloadDisplay()
                }
            }
            .onChange(of: searchTerm) {_, _ in
                filterSongRecords()
            }
            .onChange(of: isTimeTravelling) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: isTimeTravellingKey)
                if !isTimeTravelling {
                    playDataDate = .now
                }
            }
            .onChange(of: playDataDate) { oldValue, newValue in
                if !isSystemChangingCalendarDate,
                   !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    reloadDisplay()
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord):
                    ScoreViewer(songRecord: songRecord, noteCount: noteCount)
                    .automaticNavigationTransition(id: songRecord.title, in: scoresNamespace)
                case .scoreHistory(let songTitle, let level, let noteCount):
                    ScoreHistoryViewer(songTitle: songTitle, level: level, noteCount: noteCount)
                case .textageViewer(let songTitle, let level, let playSide, let playType):
                    TextageViewer(songTitle: songTitle, level: level, playSide: playSide, playType: playType)
                default: Color.clear
                }
            }
        }
    }
}

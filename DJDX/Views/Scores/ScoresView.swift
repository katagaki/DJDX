//
//  ScoresView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import SwiftUI

struct ScoresView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @State var dataState: DataState = .initializing

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: true, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: [], "ScoresView.DifficultyFilters") var difficultiesToShow: Set<IIDXDifficulty>
    @AppStorage(wrappedValue: [], "ScoresView.LevelFilters") var levelsToShow: Set<IIDXLevel>
    @AppStorage(wrappedValue: [], "ScoresView.ClearTypeFilters") var clearTypesToShow: Set<IIDXClearType>
    @AppStorage(wrappedValue: [], "ScoresView.DJLevelFilters") var djLevelsToShow: Set<IIDXDJLevel>
    @AppStorage(wrappedValue: [], "ScoresView.VersionFilters") var versionsToShow: Set<String>
    @AppStorage(wrappedValue: .lastPlayDate, "ScoresView.SortOrder") var sortMode: SortMode
    @AppStorage(wrappedValue: .descending, "ScoresView.SortDirection") var sortOrder: SortOrder

    @State var playDataDate: Date = .now

    @State var songRecords: [IIDXSongRecord]?
    @State var songRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = [:]

    @State var songCompactTitles: [String: IIDXSong] = [:]
    @State var songNoteCounts: [String: IIDXNoteCount] = [:]

    @State var searchTerm: String = ""
    @State var searchResults: [IIDXSongRecord]?

    @State var isSystemChangingFilterAndSort: Bool = false
    @State var isSystemChangingCalendarDate: Bool = false
    @State var isSystemChangingAllRecords: Bool = false

    var isTimeTravellingKey: String = "ScoresView.IsTimeTravelling"
    @State var isTimeTravelling: Bool

    let actor = DataFetcher()

    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @Namespace var scoresNamespace

    var effectiveLevel: IIDXLevel {
        levelsToShow.count == 1 ? levelsToShow.first! : .all
    }

    var effectiveDifficulty: IIDXDifficulty {
        difficultiesToShow.count == 1 ? difficultiesToShow.first! : .all
    }

    static let allLevels: [(IIDXLevel, KeyPath<IIDXSongRecord, IIDXLevelScore>)] = [
        (.beginner, \.beginnerScore),
        (.normal, \.normalScore),
        (.hyper, \.hyperScore),
        (.another, \.anotherScore),
        (.leggendaria, \.leggendariaScore)
    ]

    var conditionsForReload: [String] {
        [isShowingOnlyPlayDataWithScores.description,
         difficultiesToShow.map { String($0.rawValue) }.sorted().joined(separator: ","),
         levelsToShow.map { $0.rawValue }.sorted().joined(separator: ","),
         clearTypesToShow.map { $0.rawValue }.sorted().joined(separator: ","),
         djLevelsToShow.map { $0.rawValue }.sorted().joined(separator: ","),
         versionsToShow.sorted().joined(separator: ","),
         sortMode.rawValue,
         sortOrder.rawValue]
    }

    init() {
        self.isTimeTravelling = UserDefaults.standard.bool(forKey: isTimeTravellingKey)
    }

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach(levelEntries(from: searchResults ?? songRecords ?? []),
                        id: \.id) { entry in
                    Button {
                        navigationManager.push(.scoreViewer(songRecord: entry.songRecord), for: .scores)
                    } label: {
                        ScoreRow(
                            namespace: scoresNamespace,
                            songRecord: entry.songRecord,
                            level: entry.level,
                            score: entry.score,
                            scoreRate: songRecordClearRates[entry.songRecord]?[entry.level]
                        )
                    }
                    .listRowInsets(.init(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0))
                    .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                        dimensions[.leading]
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigator("ViewTitle.Scores")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if #available(iOS 26.0, *) {
                        Menu(playTypeToShow.displayName()) {
                            Picker("Shared.PlayType", selection: $playTypeToShow) {
                                Text(verbatim: "SP")
                                    .tag(IIDXPlayType.single)
                                Text(verbatim: "DP")
                                    .tag(IIDXPlayType.double)
                            }
                            .pickerStyle(.inline)
                        }
                    } else {
                        PlayTypePicker(playTypeToShow: $playTypeToShow)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(
                        "Shared.ShowPastData",
                        systemImage: isTimeTravelling ? "arrowshape.turn.up.backward.badge.clock.fill" :
                            "arrowshape.turn.up.backward.badge.clock"
                    ) {
                        withAnimation {
                            isTimeTravelling.toggle()
                        }
                        if !isTimeTravelling {
                            playDataDate = .now
                        }
                    }
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if dataState == .initializing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        ScoreSortAndFilter(
                            isShowingOnlyPlayDataWithScores: $isShowingOnlyPlayDataWithScores,
                            difficultiesToShow: $difficultiesToShow.animation(.snappy.speed(2.0)),
                            levelsToShow: $levelsToShow.animation(.snappy.speed(2.0)),
                            clearTypesToShow: $clearTypesToShow.animation(.snappy.speed(2.0)),
                            djLevelsToShow: $djLevelsToShow.animation(.snappy.speed(2.0)),
                            versionsToShow: $versionsToShow.animation(.snappy.speed(2.0)),
                            sortMode: $sortMode.animation(.snappy.speed(2.0)),
                            sortOrder: $sortOrder.animation(.snappy.speed(2.0)),
                            isSystemChangingFilterAndSort: $isSystemChangingFilterAndSort
                        ) {
                            reloadDisplay()
                        }
                    }
                }
            }
            .toolbarBackground(isTimeTravelling ? .hidden : .automatic, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0.0) {
                if isTimeTravelling {
                    if #available(iOS 26.0, *) {
                        DatePicker("Shared.SelectDate",
                                   selection: $playDataDate.animation(.snappy.speed(2.0)),
                                   in: ...Date.now,
                                   displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(8.0)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24.0))
                        .padding(.horizontal, 16.0)
                        .padding(.bottom, 12.0)
                    } else {
                        TabBarAccessory(placement: .top) {
                            DatePicker("Shared.SelectDate",
                                       selection: $playDataDate.animation(.snappy.speed(2.0)),
                                       in: ...Date.now,
                                       displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 18.0)
                            .padding(.bottom, 12.0)
                        }
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
            .onReceive(NotificationCenter.default.publisher(for: .dataMigrationCompleted)) { _ in
                dataState = .initializing
                reloadDisplay()
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord):
                    ScoreViewer(songRecord: songRecord, noteCount: noteCount,
                                initialLevel: songRecord.level(for: effectiveLevel, or: effectiveDifficulty))
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

//
//  ScoresView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import SwiftUI

struct ScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

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
    @State var isShowingFilterSheet: Bool = false
    @State var isSystemChangingCalendarDate: Bool = false
    @State var isSystemChangingAllRecords: Bool = false

    var isTimeTravellingKey: String = "ScoresView.IsTimeTravelling"
    @State var isTimeTravelling: Bool
    @State var isShowingDatePopover: Bool = false

    @AppStorage(wrappedValue: false, "ScoresView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.DJLevelVisible") var isDJLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreRateVisible") var isScoreRateVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScoresView.LastPlayDateVisible") var isLastPlayDateVisible: Bool

    let actor = DataFetcher()

    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @Namespace var scoresNamespace

    var effectiveLevel: IIDXLevel {
        levelsToShow.count == 1 ? levelsToShow.first! : .all
    }

    var effectiveDifficulty: IIDXDifficulty {
        difficultiesToShow.count == 1 ? difficultiesToShow.first! : .all
    }

    static var allLevels: [(IIDXLevel, KeyPath<IIDXSongRecord, IIDXLevelScore>)] {
        [
            (.beginner, \.beginnerScore),
            (.normal, \.normalScore),
            (.hyper, \.hyperScore),
            (.another, \.anotherScore),
            (.leggendaria, \.leggendariaScore)
        ]
    }

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

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
        self.isTimeTravelling = UserDefaults.standard.bool(forKey: isTimeTravellingKey)
    }

    var searchPlacement: SearchFieldPlacement {
        if #available(iOS 26.0, *) {
            .automatic
        } else {
            .navigationBarDrawer(displayMode: .always)
        }
    }

    @ViewBuilder var timeTravelButton: some View {
        let button = Button {
            withAnimation {
                isTimeTravelling.toggle()
            }
            if !isTimeTravelling {
                playDataDate = .now
            } else {
                isShowingDatePopover = true
            }
        } label: {
            Label(
                "Shared.ShowPastData",
                systemImage: isTimeTravelling ? "arrowshape.turn.up.backward.badge.clock.fill" :
                    "arrowshape.turn.up.backward.badge.clock"
            )
        }
        .popover(isPresented: $isShowingDatePopover) {
            VStack(alignment: .leading, spacing: 12.0) {
                Text("Shared.SelectDate")
                    .font(.headline)
                DatePicker("Shared.SelectDate",
                           selection: $playDataDate.animation(.snappy.speed(2.0)),
                           in: ...Date.now,
                           displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
            .frame(minWidth: 320.0)
            .padding()
            .presentationCompactAdaptation(.popover)
        }

        if #available(iOS 26.0, *) {
            if isTimeTravelling {
                button.buttonStyle(.glassProminent)
            } else {
                button
            }
        } else {
            button
                .background {
                    if isTimeTravelling {
                        Capsule().fill(Color.accentColor.opacity(0.25))
                    }
                }
        }
    }

    @ViewBuilder var sortControl: some View {
        ScoreSortMenu(
            sortMode: $sortMode.animation(.snappy.speed(2.0)),
            sortOrder: $sortOrder.animation(.snappy.speed(2.0))
        )
    }

    @ViewBuilder var filterControl: some View {
        ScoreFilterButton(
            isShowingFilterSheet: $isShowingFilterSheet,
            filterNamespace: scoresNamespace
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if searchTerm.isEmpty {
                    header
                    if !isEditingAnalytics {
                        Divider()
                        HStack {
                            Text("Analytics.Section.ScoreData")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.top, 20.0)
                        .padding(.bottom, 12.0)
                        .padding(.horizontal)
                        Divider()
                    }
                }
                if !isEditingAnalytics {
                    ForEach(levelEntries(from: searchResults ?? songRecords ?? []),
                            id: \.id) { entry in
                    Button {
                        navigationManager.push(
                            ScoresPath.scoreViewer(songRecord: entry.songRecord, initialLevel: entry.level)
                        )
                    } label: {
                        ScoreRow(
                            namespace: scoresNamespace,
                            songRecord: entry.songRecord,
                            level: entry.level,
                            score: entry.score,
                            scoreRate: songRecordClearRates[entry.songRecord]?[entry.level]
                        )
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .padding(.leading, 16.0)
                    }
                }
            }
        }
            .scrollContentBackground(.hidden)
            .background {
                LinearGradient(
                    colors: [.backgroundGradientTop, .backgroundGradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItemGroup(placement: .bottomBar) {
                        timeTravelButton
                    }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    ToolbarItemGroup(placement: .bottomBar) {
                        sortControl
                        filterControl
                    }
                } else {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        timeTravelButton
                        sortControl
                        filterControl
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
                        placement: searchPlacement,
                        prompt: "Scores.Search.Prompt")
            .sheet(isPresented: $isShowingFilterSheet) {
                ScoreFilterSheet(
                    isShowingOnlyPlayDataWithScores: $isShowingOnlyPlayDataWithScores,
                    difficultiesToShow: $difficultiesToShow.animation(.snappy.speed(2.0)),
                    levelsToShow: $levelsToShow.animation(.snappy.speed(2.0)),
                    clearTypesToShow: $clearTypesToShow.animation(.snappy.speed(2.0)),
                    djLevelsToShow: $djLevelsToShow.animation(.snappy.speed(2.0)),
                    versionsToShow: $versionsToShow.animation(.snappy.speed(2.0)),
                    isSystemChangingFilterAndSort: $isSystemChangingFilterAndSort,
                    isGenreVisible: $isGenreVisible,
                    isArtistVisible: $isArtistVisible,
                    isLevelVisible: $isLevelVisible,
                    isDJLevelVisible: $isDJLevelVisible,
                    isScoreRateVisible: $isScoreRateVisible,
                    isScoreVisible: $isScoreVisible,
                    isLastPlayDateVisible: $isLastPlayDateVisible,
                    onReset: { reloadDisplay() }
                )
                .automaticNavigationTransition(id: "ScoreFilterSheet", in: scoresNamespace)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
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
                reloadDisplay()
            }
            .onChange(of: iidxVersion) { _, _ in
                reloadDisplay()
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
            .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
                dataState = .initializing
                reloadDisplay()
            }
            .navigationDestination(for: ScoresPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord, let initialLevel):
                    ScoreViewer(songRecord: songRecord, noteCount: noteCount,
                                initialLevel: initialLevel)
                    .automaticNavigationTransition(id: "\(songRecord.title).\(initialLevel.rawValue)",
                                                   in: scoresNamespace)
                case .scoreHistory(let songTitle, let level, let noteCount):
                    ScoreHistoryViewer(songTitle: songTitle, level: level, noteCount: noteCount)
                case .textageViewer(let songTitle, let level, let playSide, let playType):
                    TextageViewer(songTitle: songTitle, level: level, playSide: playSide, playType: playType)
                }
            }
    }
}

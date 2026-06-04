import SwiftUI

struct IIDXScoresView<Header: View>: View {

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

    // Persisted store; `isScoreDataExpanded` mirrors it so a global `withAnimation`
    // can drive the collapse (animating @AppStorage directly does not work).
    var isScoreDataExpandedKey: String = "ScoresView.ScoreDataExpanded"
    @State var isScoreDataExpanded: Bool

    let actor = IIDXReader()

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
        self.isScoreDataExpanded = (UserDefaults.standard.object(
            forKey: isScoreDataExpandedKey
        ) as? Bool) ?? true
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
            if isTimeTravelling {
                // Already time travelling: tapping turns it off without showing the popover.
                withAnimation {
                    isTimeTravelling = false
                }
            } else {
                // Not time travelling: only show the popover. Selecting a non-today
                // date is what turns the feature on (see onChange of playDataDate).
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
                           selection: $playDataDate.animation(.smooth.speed(2.0)),
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
        IIDXScoreSortMenu(
            sortMode: $sortMode.animation(.smooth.speed(2.0)),
            sortOrder: $sortOrder.animation(.smooth.speed(2.0))
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
                        AnalyticsSectionHeader(
                            title: "Analytics.Section.ScoreData",
                            isCollapsible: true,
                            isExpanded: isScoreDataExpanded
                        ) {
                            withAnimation(.smooth.speed(2.0)) { isScoreDataExpanded.toggle() }
                            UserDefaults.standard.set(isScoreDataExpanded, forKey: isScoreDataExpandedKey)
                        }
                        .padding(.top, 16.0)
                        .padding(.bottom, 12.0)
                        if isScoreDataExpanded {
                            Divider()
                        }
                    }
                }
                if !isEditingAnalytics, isScoreDataExpanded || !searchTerm.isEmpty {
                    ForEach(levelEntries(from: searchResults ?? songRecords ?? []),
                            id: \.id) { entry in
                        Button {
                            navigationManager.push(
                                ScoresPath.scoreViewer(songRecord: entry.songRecord, initialLevel: entry.level)
                            )
                        } label: {
                            IIDXScoreRow(
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
                    // INFINITAS is a date-agnostic manual collection, so hide time
                    // travel. The leading spacer stays so search keeps its inset.
                    if !iidxVersion.isManualEntry {
                        ToolbarItemGroup(placement: .bottomBar) {
                            timeTravelButton
                        }
                    }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    ToolbarItemGroup(placement: .bottomBar) {
                        sortControl
                        filterControl
                    }
                } else {
                    ToolbarItemGroup(placement: .bottomBar) {
                        if !iidxVersion.isManualEntry {
                            timeTravelButton
                        }
                        Spacer()
                        sortControl
                        filterControl
                    }
                }
            }
            .background {
                if dataState == .presenting,
                   songRecords == nil || (searchResults != nil && (searchResults?.isEmpty ?? false)) {
                    ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
                } else {
                    Color.clear
                }
            }
            .searchable(text: $searchTerm,
                        placement: searchPlacement,
                        prompt: "Scores.Search.Prompt")
            .sheet(isPresented: $isShowingFilterSheet) {
                ScoreFilterSheet(
                    isShowingOnlyPlayDataWithScores: $isShowingOnlyPlayDataWithScores,
                    difficultiesToShow: $difficultiesToShow.animation(.smooth.speed(2.0)),
                    levelsToShow: $levelsToShow.animation(.smooth.speed(2.0)),
                    clearTypesToShow: $clearTypesToShow.animation(.smooth.speed(2.0)),
                    djLevelsToShow: $djLevelsToShow.animation(.smooth.speed(2.0)),
                    versionsToShow: $versionsToShow.animation(.smooth.speed(2.0)),
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
                .automaticSheetNavigationTransition(id: "ScoreFilterSheet", in: scoresNamespace)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
            .refreshable {
                NotificationCenter.default.post(name: .profileRefreshRequested, object: nil)
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
                    if !isTimeTravelling, !Calendar.current.isDateInToday(newValue) {
                        // Selecting a date other than today turns on time travelling.
                        withAnimation {
                            isTimeTravelling = true
                        }
                    }
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
                    IIDXScoreViewer(
                        songRecord: songRecord,
                        noteCount: noteCount,
                        initialLevel: initialLevel
                    )
                    .automaticNavigationTransition(id: "\(songRecord.title).\(initialLevel.rawValue)",
                                                   in: scoresNamespace)
                case .textageViewer(let songTitle, let level, let playSide, let playType):
                    TextageViewer(
                        songTitle: songTitle,
                        level: level,
                        playSide: playSide,
                        playType: playType
                    )
                }
            }
    }
}

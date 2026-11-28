import SwiftUI

struct IIDXScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @State var dataState: DataState = .initializing

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage var difficultiesToShow: Set<IIDXDifficulty>
    @AppStorage var levelsToShow: Set<IIDXLevel>
    @AppStorage var clearTypesToShow: Set<IIDXClearType>
    @AppStorage var djLevelsToShow: Set<IIDXDJLevel>
    @AppStorage var versionsToShow: Set<String>
    @AppStorage(wrappedValue: .lastPlayDate, "ScoresView.SortOrder") var sortMode: SortMode
    @AppStorage(wrappedValue: .descending, "ScoresView.SortDirection") var sortOrder: SortOrder

    @State var songRecords: [IIDXSongRecord]?
    @State var songRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = [:]

    @State var songCompactTitles: [String: IIDXSong] = [:]
    @State var songNoteCounts: [String: IIDXNoteCount] = [:]

    @State var searchTerm: String = ""
    @State var searchResults: [IIDXSongRecord]?

    @State var isSystemChangingFilterAndSort: Bool = false
    @State var isShowingFilterSheet: Bool = false
    @State var isShowingShareCard: Bool = false
    @State var isSystemChangingAllRecords: Bool = false

    @AppStorage(wrappedValue: false, "ScoresView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.DJLevelVisible") var isDJLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreRateVisible") var isScoreRateVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScoresView.LastPlayDateVisible") var isLastPlayDateVisible: Bool

    var isScoreDataExpandedKey: String = "ScoresView.ScoreDataExpanded"
    @State var isScoreDataExpanded: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool

    let actor = IIDXReader()

    @AppStorage(wrappedValue: true, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion

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
        let filterKeyPrefix = Game.stored.iidxFilterKeyPrefix
        self._isShowingOnlyPlayDataWithScores = AppStorage(
            wrappedValue: true, "\(filterKeyPrefix).ScoreAvailableOnlyFilter"
        )
        self._difficultiesToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).DifficultyFilters")
        self._levelsToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).LevelFilters")
        self._clearTypesToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).ClearTypeFilters")
        self._djLevelsToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).DJLevelFilters")
        self._versionsToShow = AppStorage(wrappedValue: [], "\(filterKeyPrefix).VersionFilters")
        self.isScoreDataExpanded = (UserDefaults.standard.object(
            forKey: isScoreDataExpandedKey
        ) as? Bool) ?? true
    }

    var searchPlacement: SearchFieldPlacement {
        .automatic
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
                    if !isEditingAnalytics, isScoreDataVisible {
                        AnalyticsSectionHeader(
                            title: "Analytics.Section.ScoreData",
                            isCollapsible: true,
                            isExpanded: isScoreDataExpanded
                        ) {
                            withAnimation(.smooth.speed(2.0)) { isScoreDataExpanded.toggle() }
                            UserDefaults.standard.set(isScoreDataExpanded, forKey: isScoreDataExpandedKey)
                        } accessory: {
                            if !(searchResults ?? songRecords ?? []).isEmpty {
                                Button("ShareCard.Title", systemImage: "square.and.arrow.up") {
                                    isShowingShareCard = true
                                }
                                .labelStyle(.iconOnly)
                                .font(.subheadline.weight(.bold))
                            }
                        }
                        .padding(.top, DesignMetrics.sectionGap)
                        .padding(.bottom, isScoreDataExpanded ? 8.0 : 0.0)
                        if isScoreDataExpanded {
                            Divider()
                        }
                    }
                }
                if !isEditingAnalytics, (isScoreDataVisible && isScoreDataExpanded) || !searchTerm.isEmpty {
                    let entries = levelEntries(from: searchResults ?? songRecords ?? [])
                    ForEach(entries, id: \.id) { entry in
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
                                scoreRate: entry.scoreRate
                            )
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
            .refreshable {
                NotificationCenter.default.post(name: .profileRefreshRequested, object: nil)
                reloadDisplay()
            }
            .scrollContentBackground(.hidden)
            .background {
                AppBackgroundGradient()
            }
            .toolbar {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) {
                    filterControl
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
                    sortMode: $sortMode.animation(.smooth.speed(2.0)),
                    sortOrder: $sortOrder.animation(.smooth.speed(2.0)),
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
                .navigationTransition(.zoom(sourceID: "ScoreFilterSheet", in: scoresNamespace))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $isShowingShareCard) {
                ShareCardComposer(
                    game: Game.stored,
                    profile: Game.stored == .iidxArcade ? .iidx(playType: playTypeToShow) : ShareCardProfile(),
                    entries: levelEntries(from: searchResults ?? songRecords ?? []).map {
                        ShareCardEntry(iidxSongRecord: $0.songRecord, level: $0.level,
                                       score: $0.score, scoreRate: $0.scoreRate, iidxVersion: iidxVersion)
                    },
                    playStyle: playTypeToShow.displayName()
                )
            }
            .onAppear {
                if dataState == .initializing {
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
            .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
                dataState = .initializing
                Task {
                    await actor.invalidateCachedRecords()
                    reloadDisplay()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .externalDataChanged)) { _ in
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
                case .textageViewer(let legacyURL, let chartViewerURL):
                    TextageViewer(legacyURL: legacyURL, chartViewerURL: chartViewerURL)
                }
            }
    }
}

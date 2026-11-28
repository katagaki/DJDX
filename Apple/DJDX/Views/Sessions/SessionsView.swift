import SwiftUI

struct SessionsView: View {
    var store: IIDXSessionStore
    var analyticsModel: AnalyticsModel
    @Binding var isEditingAnalytics: Bool
    var analyticsNamespace: Namespace.ID
    var towerNamespace: Namespace.ID

    @State var isPresentingExternalDataSources: Bool = false
    @State var isHistoryExpanded: Bool = true
    @State var isScoreDataExpanded: Bool = true
    @State var latestPlays: [IIDXCapturedPlay] = []
    @State var playHistories: [String: [IIDXCapturedPlay]] = [:]
    @State var songCompactTitles: [String: IIDXSong] = [:]
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false
    @State var hasBemaniWikiData: Bool = true
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @AppStorage(wrappedValue: [], "SessionsView.LevelFilters") var levelsToShow: Set<IIDXLevel>
    @AppStorage(wrappedValue: [], "SessionsView.DifficultyFilters") var difficultiesToShow: Set<IIDXDifficulty>
    @AppStorage(wrappedValue: [], "SessionsView.ClearTypeFilters") var clearTypesToShow: Set<IIDXClearType>
    @AppStorage(wrappedValue: [], "SessionsView.DJLevelFilters") var djLevelsToShow: Set<IIDXDJLevel>
    @AppStorage(wrappedValue: .lastPlayDate, "SessionsView.SortOrder") var sortMode: SortMode
    @AppStorage(wrappedValue: .descending, "SessionsView.SortDirection") var sortOrder: SortOrder

    @Namespace var sessionsNamespace


    var pastSessions: [IIDXPlaySession] {
        store.sessions.filter { !$0.isActive }.sorted { $0.startDate > $1.startDate }
    }

    var isPresentingActive: Binding<Bool> {
        Binding {
            store.activeSession != nil && !store.isActiveSessionMinimized
        } set: { isPresented in
            store.isActiveSessionMinimized = !isPresented
        }
    }

    var searchPlacement: SearchFieldPlacement {
        .automatic
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if !isSearching {
                    if !isEditingAnalytics, !hasBemaniWikiData {
                        sessionsCard { bemaniWikiWarning }
                            .padding(.horizontal)
                            .padding(.top, 8.0)
                    }
                    if !isEditingAnalytics {
                        historySection
                            .padding(.top, 20.0)
                    }
                    AnalyticsView(model: analyticsModel,
                                  isEditing: $isEditingAnalytics,
                                  analyticsNamespace: analyticsNamespace,
                                  towerNamespace: towerNamespace)
                }
                if !isEditingAnalytics, isScoreDataVisible || isSearching {
                    scoreDataSection
                }
            }
            .padding(.bottom, 8.0)
        }
        .background {
            AppBackgroundGradient()
        }
        .searchable(text: $searchTerm,
                    placement: searchPlacement,
                    prompt: "Scores.Search.Prompt")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                SessionsHelpMenu()
            }
            ToolbarSpacer(.fixed, placement: .bottomBar)
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.fixed, placement: .bottomBar)
            ToolbarItemGroup(placement: .bottomBar) {
                filterControl
            }
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            SessionScoreFilterSheet(
                sortMode: $sortMode.animation(.smooth.speed(2.0)),
                sortOrder: $sortOrder.animation(.smooth.speed(2.0)),
                levelsToShow: $levelsToShow.animation(.smooth.speed(2.0)),
                difficultiesToShow: $difficultiesToShow.animation(.smooth.speed(2.0)),
                clearTypesToShow: $clearTypesToShow.animation(.smooth.speed(2.0)),
                djLevelsToShow: $djLevelsToShow.animation(.smooth.speed(2.0))
            )
            .navigationTransition(.zoom(sourceID: "ScoreFilterSheet", in: sessionsNamespace))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
        }
        .onAppear {
            store.bootstrap()
        }
        .task {
            hasBemaniWikiData = await IIDXReader().bemaniWikiSongCount() > 0
            await IIDXSessionSongInfo.shared.reload()
            songCompactTitles = IIDXSessionSongInfo.shared.songs
            reloadScores()
        }
        .onReceive(NotificationCenter.default.publisher(for: .externalDataChanged)) { _ in
            Task {
                hasBemaniWikiData = await IIDXReader().bemaniWikiSongCount() > 0
                await IIDXSessionSongInfo.shared.reload()
                songCompactTitles = IIDXSessionSongInfo.shared.songs
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playSessionDidChange)
            .debounce(for: .seconds(0.4), scheduler: RunLoop.main)) { _ in
            store.loadSessions()
            reloadScores()
        }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .debounce(for: .seconds(0.4), scheduler: RunLoop.main)) { _ in
            reloadScores()
        }
        .fullScreenCover(isPresented: isPresentingActive) {
            ActiveSessionView(store: store)
        }
        .sheet(isPresented: $isPresentingExternalDataSources) {
            NavigationStack {
                MoreExternalDataSources()
            }
        }
    }

    private func reloadScores() {
        var allPlays: [IIDXCapturedPlay] = []
        for session in store.sessions {
            allPlays.append(contentsOf: store.plays(for: session))
        }
        allPlays = allPlays.filter { play in
            guard play.state == .done || play.state == .needsReview else { return false }
            guard play.difficulty > 0 else { return false }
            guard let title = play.songTitle, !title.isEmpty else { return false }
            return true
        }
        var histories: [String: [IIDXCapturedPlay]] = [:]
        for play in allPlays {
            histories[play.chartKey(), default: []].append(play)
        }
        for key in histories.keys {
            histories[key]?.sort { $0.captureDate > $1.captureDate }
        }
        playHistories = histories
        latestPlays = histories.values.compactMap(\.first).sorted { $0.captureDate > $1.captureDate }
    }
}

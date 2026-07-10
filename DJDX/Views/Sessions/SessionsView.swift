import SwiftUI

struct SessionsView: View {
    var store: IIDXSessionStore
    var analyticsModel: AnalyticsModel
    @Binding var isEditingAnalytics: Bool
    var analyticsNamespace: Namespace.ID
    var towerNamespace: Namespace.ID

    @State var isPresentingActive: Bool = false
    @State var isPresentingExternalDataSources: Bool = false
    @State var isHistoryExpanded: Bool = true
    @State var isScoreDataExpanded: Bool = true
    @State var latestPlays: [IIDXCapturedPlay] = []
    @State var playHistories: [String: [IIDXCapturedPlay]] = [:]
    @State var songCompactTitles: [String: IIDXSong] = [:]
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false
    @AppStorage(wrappedValue: false, "ExternalData.BemaniWiki2nd.Enabled") var isBemaniWikiEnabled: Bool
    @AppStorage(wrappedValue: true, "More.General.ShowAnalytics") var showAnalytics: Bool
    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @AppStorage(wrappedValue: [], "SessionsView.LevelFilters") var levelsToShow: Set<IIDXLevel>
    @AppStorage(wrappedValue: [], "SessionsView.DifficultyFilters") var difficultiesToShow: Set<IIDXDifficulty>
    @AppStorage(wrappedValue: [], "SessionsView.ClearTypeFilters") var clearTypesToShow: Set<IIDXClearType>
    @AppStorage(wrappedValue: [], "SessionsView.DJLevelFilters") var djLevelsToShow: Set<IIDXDJLevel>
    @AppStorage(wrappedValue: .lastPlayDate, "SessionsView.SortOrder") var sortMode: SortMode
    @AppStorage(wrappedValue: .descending, "SessionsView.SortDirection") var sortOrder: SortOrder

    @Namespace var sessionsNamespace

    private let reader = IIDXReader()

    var pastSessions: [IIDXPlaySession] {
        store.sessions.filter { !$0.isActive }.sorted { $0.startDate > $1.startDate }
    }

    var searchPlacement: SearchFieldPlacement {
        if #available(iOS 26.0, *) {
            .automatic
        } else {
            .navigationBarDrawer(displayMode: .always)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if !isSearching {
                    if !isEditingAnalytics, !isBemaniWikiEnabled || store.activeSession != nil {
                        VStack(spacing: 12.0) {
                            if !isBemaniWikiEnabled {
                                sessionsCard { bemaniWikiWarning }
                            }
                            if let active = store.activeSession {
                                Button {
                                    isPresentingActive = true
                                } label: {
                                    sessionsCard { resumeCard(active) }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8.0)
                    }
                    if !isEditingAnalytics {
                        historySection
                            .padding(.top, 20.0)
                    }
                    if showAnalytics {
                        AnalyticsView(model: analyticsModel,
                                      isEditing: $isEditingAnalytics,
                                      analyticsNamespace: analyticsNamespace,
                                      towerNamespace: towerNamespace)
                    }
                }
                if !isEditingAnalytics {
                    scoreDataSection
                        .padding(.top, isSearching ? 8.0 : 20.0)
                }
            }
            .padding(.bottom, 8.0)
        }
        .background {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .searchable(text: $searchTerm,
                    placement: searchPlacement,
                    prompt: "Scores.Search.Prompt")
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItemGroup(placement: .bottomBar) {
                    SessionsHelpMenu()
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
                    SessionsHelpMenu()
                    Spacer()
                    sortControl
                    filterControl
                }
            }
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            SessionScoreFilterSheet(
                levelsToShow: $levelsToShow.animation(.smooth.speed(2.0)),
                difficultiesToShow: $difficultiesToShow.animation(.smooth.speed(2.0)),
                clearTypesToShow: $clearTypesToShow.animation(.smooth.speed(2.0)),
                djLevelsToShow: $djLevelsToShow.animation(.smooth.speed(2.0))
            )
            .automaticSheetNavigationTransition(id: "ScoreFilterSheet", in: sessionsNamespace)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .onAppear {
            store.bootstrap()
            if store.activeSession != nil { isPresentingActive = true }
        }
        .task {
            songCompactTitles = await reader.songCompactTitles()
            reloadScores()
        }
        .onChange(of: store.activeSession?.id) { _, newValue in
            isPresentingActive = newValue != nil
        }
        .onChange(of: store.pendingCaptureRequest) { _, pending in
            if pending, store.activeSession != nil { isPresentingActive = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playSessionDidChange)
            .receive(on: RunLoop.main)) { _ in
            store.loadSessions()
            reloadScores()
        }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .receive(on: RunLoop.main)) { _ in
            reloadScores()
        }
        .fullScreenCover(isPresented: $isPresentingActive) {
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

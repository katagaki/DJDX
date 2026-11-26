import SwiftUI

struct PopnScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @AppStorage(wrappedValue: PopnVersion.highCheers, "Global.Popn.Version") var popnVersion: PopnVersion
    @AppStorage(wrappedValue: PopnSortMode.title, "PopnScoresView.SortMode")
    var sortMode: PopnSortMode
    @AppStorage(wrappedValue: SortOrder.ascending, "PopnScoresView.SortOrder")
    var sortOrder: SortOrder
    @AppStorage(wrappedValue: [], "PopnScoresView.DifficultyFilters")
    var difficultiesToShow: Set<PopnDifficulty>
    @AppStorage(wrappedValue: [], "PopnScoresView.LevelFilters")
    var levelsToShow: Set<String>
    @AppStorage(wrappedValue: [], "PopnScoresView.ClearTypeFilters")
    var clearTypesToShow: Set<PopnClearType>
    @AppStorage(wrappedValue: [], "PopnScoresView.RankFilters")
    var ranksToShow: Set<PopnRank>

    var isScoreDataExpandedKey: String = "PopnScoresView.ScoreDataExpanded"
    @State var isScoreDataExpanded: Bool

    @State var dataState: DataState = .initializing
    @State var records: [PopnSongRecord] = []
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false

    @Namespace var popnNamespace

    let fetcher = PopnReader()

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
        self.isScoreDataExpanded = (UserDefaults.standard.object(
            forKey: isScoreDataExpandedKey
        ) as? Bool) ?? true
    }

    var filteredRecords: [PopnSongRecord] {
        var result = records
        if !searchTerm.isEmpty {
            let term = searchTerm.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(term) || $0.genre.lowercased().contains(term)
            }
        }
        let filters = filters
        return result.filter { filters.matches($0) }
    }

    var filters: PopnFilterOptions {
        PopnFilterOptions(difficulties: difficultiesToShow,
                                  levels: levelsToShow,
                                  clearTypes: clearTypesToShow,
                                  ranks: ranksToShow)
    }

    var availableLevels: [String] {
        Set(records.map { $0.level }).subtracting([0]).sorted().map { String($0) }
    }

    var sortedRecords: [PopnSongRecord] {
        let base = filteredRecords
        let sorted: [PopnSongRecord]
        switch sortMode {
        case .title:
            sorted = base.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .score:
            sorted = base.sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .level:
            sorted = base.sorted { lhs, rhs in
                if lhs.level != rhs.level { return lhs.level < rhs.level }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .medal:
            sorted = base.sorted { lhs, rhs in
                let lhsRank = medalRank(lhs)
                let rhsRank = medalRank(rhs)
                if lhsRank != rhsRank { return lhsRank > rhsRank }
                return lhs.score > rhs.score
            }
        }
        let ordered = sortOrder == .ascending ? sorted : sorted.reversed()
        guard sortMode == .medal else { return ordered }
        let hasPlay = { (record: PopnSongRecord) in record.medalEnum != .noPlay }
        return ordered.filter(hasPlay) + ordered.filter { !hasPlay($0) }
    }

    func medalRank(_ record: PopnSongRecord) -> Int {
        PopnMedal.sorted.firstIndex(of: record.medalEnum) ?? PopnMedal.sorted.count
    }

    @ViewBuilder var sortControl: some View {
        Menu("Shared.Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Shared.Sort", selection: $sortMode.animation(.smooth.speed(2.0))) {
                ForEach(PopnSortMode.allCases, id: \.self) { mode in
                    Text(LocalizedStringKey(mode.rawValue))
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
            Section {
                Picker("Shared.Sort.Order", selection: $sortOrder.animation(.smooth.speed(2.0))) {
                    Label("Shared.Sort.Ascending", systemImage: "arrow.up")
                        .tag(SortOrder.ascending)
                    Label("Shared.Sort.Descending", systemImage: "arrow.down")
                        .tag(SortOrder.descending)
                }
                .pickerStyle(.inline)
            }
        }
        .menuOrder(.fixed)
        .menuActionDismissBehavior(.disabled)
    }

    @ViewBuilder var filterControl: some View {
        Button("Shared.Filter", systemImage: "line.3.horizontal.decrease") {
            isShowingFilterSheet = true
        }
        .matchedTransitionSource(id: "PopnScoreFilterSheet", in: popnNamespace)
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
                    ForEach(sortedRecords, id: \.self) { record in
                        PopnScoreRow(record: record)
                            .contentShape(.rect)
                        Divider()
                            .padding(.leading, 16.0)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AppBackgroundGradient()
        }
        .searchable(text: $searchTerm, prompt: "Scores.Search.Prompt")
        .refreshable {
            NotificationCenter.default.post(name: .profileRefreshRequested, object: nil)
            await reload()
        }
        .toolbar {
            if #available(iOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) {
                    sortControl
                    filterControl
                }
            } else {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    sortControl
                    filterControl
                }
            }
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            PopnScoreFilterSheet(
                difficultiesToShow: $difficultiesToShow.animation(.smooth.speed(2.0)),
                levelsToShow: $levelsToShow.animation(.smooth.speed(2.0)),
                clearTypesToShow: $clearTypesToShow.animation(.smooth.speed(2.0)),
                ranksToShow: $ranksToShow.animation(.smooth.speed(2.0)),
                availableLevels: availableLevels,
                onReset: {}
            )
            .navigationTransition(.zoom(sourceID: "PopnScoreFilterSheet", in: popnNamespace))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
        }
        .background {
            if dataState == .presenting && records.isEmpty {
                ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
            }
        }
        .task {
            if dataState == .initializing {
                await reload()
            }
        }
        .onChange(of: popnVersion) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    func reload() async {
        dataState = .loading
        let latest = await fetcher.latestSongRecords(for: popnVersion)
        await MainActor.run {
            withAnimation(.smooth.speed(2.0)) {
                records = latest
                dataState = .presenting
            }
        }
    }
}

import SwiftUI

struct DDRScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: DDRPlayStyle.single, "Global.DDR.Style") var ddrStyleToShow: DDRPlayStyle
    @AppStorage(wrappedValue: true, "DDRScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayedCharts: Bool
    @AppStorage(wrappedValue: DDRSortMode.title, "DDRScoresView.SortMode") var sortMode: DDRSortMode
    @AppStorage(wrappedValue: SortOrder.ascending, "DDRScoresView.SortOrder") var sortOrder: SortOrder
    @AppStorage(wrappedValue: [], "DDRScoresView.DifficultyFilters") var difficultiesToShow: Set<DDRDifficulty>
    @AppStorage(wrappedValue: [], "DDRScoresView.LevelFilters") var levelsToShow: Set<Int>
    @AppStorage(wrappedValue: [], "DDRScoresView.ClearLampFilters") var clearLampsToShow: Set<String>
    @AppStorage(wrappedValue: [], "DDRScoresView.RankFilters") var ranksToShow: Set<String>

    @State var dataState: DataState = .initializing
    @State var records: [DDRSongRecord] = []
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false

    @Namespace var ddrNamespace

    let fetcher = DDRReader()

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
    }

    var styleRecords: [DDRSongRecord] {
        records.filter { $0.styleEnum == ddrStyleToShow }
    }

    var availableLevels: [Int] {
        Set(styleRecords.map { $0.level }.filter { $0 > 0 }).sorted()
    }

    var availableClearLamps: [String] {
        DDRSongRecord.orderedClearLamps(Set(styleRecords.compactMap { $0.clearKind.isEmpty ? nil : $0.clearKind }))
    }

    var availableRanks: [String] {
        DDRSongRecord.orderedRanks(Set(styleRecords.compactMap { $0.rank.isEmpty ? nil : $0.rank }))
    }

    var filteredRecords: [DDRSongRecord] {
        var result = styleRecords
        if isShowingOnlyPlayedCharts {
            result = result.filter { $0.hasScore }
        }
        if !searchTerm.isEmpty {
            let term = searchTerm.lowercased()
            result = result.filter { $0.title.lowercased().contains(term) }
        }
        if !difficultiesToShow.isEmpty {
            result = result.filter { difficultiesToShow.contains($0.difficultyEnum) }
        }
        if !levelsToShow.isEmpty {
            result = result.filter { levelsToShow.contains($0.level) }
        }
        if !clearLampsToShow.isEmpty {
            result = result.filter { clearLampsToShow.contains($0.clearKind) }
        }
        if !ranksToShow.isEmpty {
            result = result.filter { ranksToShow.contains($0.rank) }
        }
        return result
    }

    var sortedRecords: [DDRSongRecord] {
        let base = filteredRecords
        let sorted: [DDRSongRecord]
        switch sortMode {
        case .title:
            sorted = base.sorted { titleThenDifficulty($0, $1) }
        case .score:
            sorted = base.sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .clearLamp:
            sorted = base.sorted { lhs, rhs in
                if lhs.clearLampSortIndex != rhs.clearLampSortIndex {
                    return lhs.clearLampSortIndex < rhs.clearLampSortIndex
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .level:
            sorted = base.sorted { lhs, rhs in
                if lhs.level != rhs.level { return lhs.level < rhs.level }
                return titleThenDifficulty(lhs, rhs)
            }
        }
        return sortOrder == .ascending ? sorted : sorted.reversed()
    }

    func titleThenDifficulty(_ lhs: DDRSongRecord, _ rhs: DDRSongRecord) -> Bool {
        if lhs.titleCompact() != rhs.titleCompact() {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        let lhsRank = DDRDifficulty.sorted.firstIndex(of: lhs.difficultyEnum) ?? Int.max
        let rhsRank = DDRDifficulty.sorted.firstIndex(of: rhs.difficultyEnum) ?? Int.max
        return lhsRank < rhsRank
    }

    @ViewBuilder var sortControl: some View {
        Menu("Shared.Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Shared.Sort", selection: $sortMode.animation(.smooth.speed(2.0))) {
                ForEach(DDRSortMode.allCases, id: \.self) { mode in
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
        .automaticSheetMatchedTransitionSource(id: "DDRScoreFilterSheet", in: ddrNamespace)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if searchTerm.isEmpty {
                    header
                }
                if !isEditingAnalytics {
                    ForEach(sortedRecords, id: \.self) { record in
                        DDRScoreRow(record: record)
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
            DDRScoreFilterSheet(
                isShowingOnlyPlayedCharts: $isShowingOnlyPlayedCharts.animation(.smooth.speed(2.0)),
                difficultiesToShow: $difficultiesToShow.animation(.smooth.speed(2.0)),
                levelsToShow: $levelsToShow.animation(.smooth.speed(2.0)),
                clearLampsToShow: $clearLampsToShow.animation(.smooth.speed(2.0)),
                ranksToShow: $ranksToShow.animation(.smooth.speed(2.0)),
                availableLevels: availableLevels,
                availableClearLamps: availableClearLamps,
                availableRanks: availableRanks,
                onReset: {
                }
            )
            .automaticSheetNavigationTransition(id: "DDRScoreFilterSheet", in: ddrNamespace)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
        }
        .background {
            if dataState == .presenting && filteredRecords.isEmpty {
                ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
            }
        }
        .task {
            if dataState == .initializing {
                await reload()
            }
        }
        .onChange(of: ddrVersion) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    func reload() async {
        dataState = .loading
        let latest = await fetcher.latestSongRecords(for: ddrVersion)
        await MainActor.run {
            withAnimation(.smooth.speed(2.0)) {
                records = latest
                dataState = .presenting
            }
        }
    }
}

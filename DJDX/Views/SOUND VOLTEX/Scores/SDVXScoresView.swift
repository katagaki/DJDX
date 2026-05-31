import SwiftUI

struct SDVXScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: SDVXSortMode.title, "SDVXScoresView.SortMode") var sortMode: SDVXSortMode
    @AppStorage(wrappedValue: SortOrder.ascending, "SDVXScoresView.SortOrder") var sortOrder: SortOrder
    @AppStorage(wrappedValue: [], "SDVXScoresView.DifficultyFilters") var difficultiesToShow: Set<SDVXDifficulty>
    @AppStorage(wrappedValue: [], "SDVXScoresView.LevelFilters") var levelBucketsToShow: Set<Double>
    @AppStorage(wrappedValue: [], "SDVXScoresView.ClearTypeFilters") var clearTypesToShow: Set<SDVXClearType>
    @AppStorage(wrappedValue: [], "SDVXScoresView.GradeFilters") var gradesToShow: Set<SDVXGrade>

    // Persisted store; `isScoreDataExpanded` mirrors it so a global `withAnimation`
    // can drive the collapse (animating @AppStorage directly does not work).
    var isScoreDataExpandedKey: String = "SDVXScoresView.ScoreDataExpanded"
    @State var isScoreDataExpanded: Bool

    @State var dataState: DataState = .initializing
    @State var records: [SDVXSongRecord] = []
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false

    @Namespace var sdvxNamespace

    let fetcher = SDVXReader()

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
        self.isScoreDataExpanded = (UserDefaults.standard.object(
            forKey: isScoreDataExpandedKey
        ) as? Bool) ?? true
    }

    var filteredRecords: [SDVXSongRecord] {
        var result = records
        if !searchTerm.isEmpty {
            let term = searchTerm.lowercased()
            result = result.filter { $0.title.lowercased().contains(term) }
        }
        if !difficultiesToShow.isEmpty {
            result = result.filter { difficultiesToShow.contains($0.difficultyEnum) }
        }
        if !levelBucketsToShow.isEmpty {
            result = result.filter { levelBucketsToShow.contains(levelBucket($0.level)) }
        }
        if !clearTypesToShow.isEmpty {
            result = result.filter { clearTypesToShow.contains($0.clearTypeEnum) }
        }
        if !gradesToShow.isEmpty {
            result = result.filter { gradesToShow.contains($0.gradeEnum) }
        }
        return result
    }

    // Group decimal levels into 0.5-wide buckets (e.g. 17.0–17.4 -> 17.0).
    func levelBucket(_ level: String) -> Double {
        let value = Double(level) ?? 0.0
        return (value * 2.0).rounded(.down) / 2.0
    }

    var availableLevelBuckets: [Double] {
        Set(records.map { levelBucket($0.level) }).sorted()
    }

    var sortedRecords: [SDVXSongRecord] {
        let base = filteredRecords
        let sorted: [SDVXSongRecord]
        switch sortMode {
        case .title:
            sorted = base.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .clearType:
            sorted = base.sorted { lhs, rhs in
                let lhsRank = clearRank(lhs)
                let rhsRank = clearRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.highScore > rhs.highScore
            }
        case .score:
            sorted = base.sorted { lhs, rhs in
                if lhs.highScore != rhs.highScore { return lhs.highScore < rhs.highScore }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .level:
            sorted = base.sorted { lhs, rhs in
                let lhsLevel = Double(lhs.level) ?? 0.0
                let rhsLevel = Double(rhs.level) ?? 0.0
                if lhsLevel != rhsLevel { return lhsLevel < rhsLevel }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
        return sortOrder == .ascending ? sorted : sorted.reversed()
    }

    // Lower rank is a better clear (PERFECT ULTIMATE CHAIN ... PLAYED), so an
    // ascending sort lists COMP-tier clears before PLAY-tier ones.
    func clearRank(_ record: SDVXSongRecord) -> Int {
        SDVXClearType.sorted.firstIndex(of: record.clearTypeEnum) ?? SDVXClearType.sorted.count
    }

    @ViewBuilder var sortControl: some View {
        Menu("Shared.Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Shared.Sort", selection: $sortMode.animation(.snappy.speed(2.0))) {
                ForEach(SDVXSortMode.allCases, id: \.self) { mode in
                    Text(LocalizedStringKey(mode.rawValue))
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
            Section {
                Picker("Shared.Sort.Order", selection: $sortOrder.animation(.snappy.speed(2.0))) {
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
        .automaticSheetMatchedTransitionSource(id: "SDVXScoreFilterSheet", in: sdvxNamespace)
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
                        SDVXScoreRow(record: record)
                            .contentShape(.rect)
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
            SDVXScoreFilterSheet(
                difficultiesToShow: $difficultiesToShow.animation(.snappy.speed(2.0)),
                levelBucketsToShow: $levelBucketsToShow.animation(.snappy.speed(2.0)),
                clearTypesToShow: $clearTypesToShow.animation(.snappy.speed(2.0)),
                gradesToShow: $gradesToShow.animation(.snappy.speed(2.0)),
                availableLevelBuckets: availableLevelBuckets,
                onReset: {
                    // No additional handling needed when filters are reset
                }
            )
            .automaticSheetNavigationTransition(id: "SDVXScoreFilterSheet", in: sdvxNamespace)
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
        .onChange(of: sdvxVersion) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    func reload() async {
        dataState = .loading
        let latest = await fetcher.latestSongRecords(for: sdvxVersion)
        await MainActor.run {
            withAnimation(.smooth.speed(2.0)) {
                records = latest
                dataState = .presenting
            }
        }
    }
}

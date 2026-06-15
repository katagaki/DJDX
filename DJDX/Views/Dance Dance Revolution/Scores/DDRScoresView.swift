import SwiftUI

struct DDRScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: DDRPlayStyle.single, "Global.DDR.Style") var ddrStyleToShow: DDRPlayStyle
    @AppStorage(wrappedValue: true, "DDRScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayedCharts: Bool

    @State var dataState: DataState = .initializing
    @State var records: [DDRSongRecord] = []
    @State var searchTerm: String = ""

    let fetcher = DDRReader()

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
    }

    var filteredRecords: [DDRSongRecord] {
        var result = records.filter { $0.styleEnum == ddrStyleToShow }
        if isShowingOnlyPlayedCharts {
            result = result.filter { $0.hasScore }
        }
        if !searchTerm.isEmpty {
            let term = searchTerm.lowercased()
            result = result.filter { $0.title.lowercased().contains(term) }
        }
        return result.sorted { lhs, rhs in
            if lhs.titleCompact() != rhs.titleCompact() {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            let lhsRank = DDRDifficulty.sorted.firstIndex(of: lhs.difficultyEnum) ?? Int.max
            let rhsRank = DDRDifficulty.sorted.firstIndex(of: rhs.difficultyEnum) ?? Int.max
            return lhsRank < rhsRank
        }
    }

    @ViewBuilder var filterControl: some View {
        Menu {
            Toggle(
                .scoresFilterShowWithScoreOnly, systemImage: "trophy.fill",
                isOn: $isShowingOnlyPlayedCharts.animation(.smooth.speed(2.0))
            )
        } label: {
            Label("Shared.Filter", systemImage: "line.3.horizontal.decrease")
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if searchTerm.isEmpty {
                    header
                }
                if !isEditingAnalytics {
                    ForEach(filteredRecords, id: \.self) { record in
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
                    filterControl
                }
            } else {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    filterControl
                }
            }
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

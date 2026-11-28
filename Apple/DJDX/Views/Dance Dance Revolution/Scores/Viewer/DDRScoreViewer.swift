import SwiftUI

struct DDRScoreViewer: View {

    var songRecords: [DDRSongRecord]
    var initialDifficulty: DDRDifficulty

    @State private var selectedDifficulty: DDRDifficulty = .unknown
    @State private var scoreHistory: [Date: Int] = [:]

    private let fetcher = DDRReader()

    private var songRecord: DDRSongRecord {
        songRecords.first { $0.difficultyEnum == selectedDifficulty } ?? songRecords.first ?? DDRSongRecord()
    }

    private var title: String {
        songRecords.first?.title ?? songRecord.title
    }

    var body: some View {
        List {
            Section {
                Text(verbatim: title)
                    .font(.title)
                    .fontWeight(.heavy)
                    .fontWidth(.compressed)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8.0)
                    .padding(.horizontal, 20.0)
            }
            .sectionStyle()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            Section {
                headline()
                VStack(alignment: .leading, spacing: 8.0) {
                    SDVXDetailRow("CLEAR TYPE",
                                  value: songRecord.clearDisplay.isEmpty ? "-" : songRecord.clearDisplay,
                                  style: DDRSongRecord.clearColor(for: songRecord.clearKind))
                    SDVXDetailRow("SCORE", value: songRecord.score,
                                  style: LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                    SDVXDetailRow("FLARE RANK",
                                  value: songRecord.flareRank.isEmpty ? "-" : songRecord.flareRank.uppercased(),
                                  style: Color.orange)
                    SDVXDetailRow("FLARE SKILL", value: songRecord.flareSkill, style: Color.orange)
                }
                ScoreHistoryRows(
                    history: scoreHistory,
                    yDomain: ScoreHistoryChart.zoomedDomain(for: scoreHistory, step: 50_000, upperBound: 1_000_000),
                    thresholds: Self.historyThresholds
                )
            }
            .clearSection()
            if selectedDifficulty != .unknown {
                ChartNotesSection(game: .danceDanceRevolution, title: title,
                                  chart: songRecord.chartNoteTarget.chart)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .navigator("ViewTitle.Scores.Song", group: true, inline: true)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0.0, for: .scrollContent)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0.0) {
            difficultySwitcher()
                .padding(.horizontal, 20.0)
                .padding(.bottom, 8.0)
        }
        .onAppear {
            if selectedDifficulty == .unknown {
                selectedDifficulty = songRecords.contains(where: { $0.difficultyEnum == initialDifficulty })
                    ? initialDifficulty
                    : (songRecords.first?.difficultyEnum ?? .unknown)
            }
        }
        .task(id: selectedDifficulty) {
            scoreHistory = await fetcher.scoreHistory(songIndex: songRecord.songIndex,
                                                      title: songRecord.title,
                                                      style: songRecord.styleEnum,
                                                      difficulty: songRecord.difficultyEnum)
        }
    }

    static let historyThresholds: [ScoreHistoryThreshold] = [
        ("aaa", 990_000.0, 0.7),
        ("aa_p", 950_000.0, 0.55),
        ("aa", 900_000.0, 0.45),
        ("a_p", 850_000.0, 0.4)
    ].map { rank, value, opacity in
        ScoreHistoryThreshold(label: DDRSongRecord.rankDisplay(forStem: rank), value: value,
                              color: DDRSongRecord.rankColor(forStem: rank), opacity: opacity)
    }

    @ViewBuilder
    private func difficultySwitcher() -> some View {
        let segments: [DifficultySegmentedPicker<DDRDifficulty>.Segment] = songRecords.map { record in
            DifficultySegmentedPicker<DDRDifficulty>.Segment(
                tag: record.difficultyEnum,
                number: record.level > 0 ? String(record.level) : "-",
                name: Text(verbatim: record.difficultyEnum.rawValue),
                color: record.difficultyEnum.color
            )
        }
        DifficultySegmentedPicker(segments: segments, selection: $selectedDifficulty)
            .padding(.top, 4.0)
    }

    @ViewBuilder
    func headline() -> some View {
        HStack(spacing: 16.0) {
            if !songRecord.rankDisplay.isEmpty {
                Text(verbatim: songRecord.rankDisplay)
                    .foregroundStyle(DDRSongRecord.rankColor(forStem: songRecord.rank))
                    .strokeText(color: .black, width: 0.6)
            }
            Spacer()
            Text(songRecord.score, format: .number)
                .font(.scoreline(.title))
                .fontWidth(.standard)
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
        }
        .font(.title)
        .fontWidth(.expanded)
        .fontWeight(.black)
    }
}

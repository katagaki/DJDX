import SwiftUI

struct SDVXScoreViewer: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.openURL) var openURL

    var songRecords: [SDVXSongRecord]
    var initialDifficulty: SDVXDifficulty

    @State private var selectedDifficulty: SDVXDifficulty = .unknown
    @State private var sdvxInChart: SDVXInChart?
    @State private var scoreHistory: [Date: Int] = [:]

    private let fetcher = SDVXReader()

    private var songRecord: SDVXSongRecord {
        songRecords.first { $0.difficultyEnum == selectedDifficulty } ?? songRecords.first ?? SDVXSongRecord()
    }

    private var difficulty: SDVXDifficulty { songRecord.difficultyEnum }

    private var title: String {
        songRecords.first?.title ?? songRecord.title
    }

    var body: some View {
        List {
            Section {
                header()
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            Section {
                headline()
                VStack(alignment: .leading, spacing: 8.0) {
                    SDVXDetailRow("CLEAR TYPE",
                                  value: songRecord.clearTypeEnum.abbreviation,
                                  style: songRecord.clearTypeEnum.color)
                    SDVXDetailRow("GRADE", value: songRecord.grade, style: LinearGradient.sdvxGrade,
                                  outlineColor: .sdvxGradeOutline, outlineWidth: 0.3)
                    SDVXScoreDetailRow("HIGH SCORE", value: songRecord.highScore)
                    SDVXScoreDetailRow("EX SCORE", value: songRecord.exScore)
                }
                HStack(spacing: 0.0) {
                    SDVXNoteTypeDetailRow("PLAYS", value: songRecord.playCount, style: Color.secondary)
                    SDVXNoteTypeDetailRow("CLEARS", value: songRecord.clearCount, style: Color.green)
                    SDVXNoteTypeDetailRow("UC", value: songRecord.ultimateChainCount, style: Color.pink)
                    SDVXNoteTypeDetailRow("PERFECT", value: songRecord.perfectCount, style: Color.yellow)
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                ScoreHistoryRows(
                    history: scoreHistory,
                    yDomain: ScoreHistoryChart.zoomedDomain(for: scoreHistory, step: 100_000, upperBound: 10_000_000),
                    thresholds: Self.historyThresholds
                )
                chartActions()
            }
            if selectedDifficulty != .unknown {
                ChartNotesSection(game: .soundVoltex, title: title, chart: difficulty.rawValue)
            }
        }
        .listSectionSpacing(.compact)
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
            sdvxInChart = await fetcher.sdvxInChart(title: songRecord.title, difficulty: difficulty)
            scoreHistory = await fetcher.scoreHistory(title: songRecord.title, difficulty: difficulty)
        }
    }

    static let historyThresholds: [ScoreHistoryThreshold] = [
        (SDVXGrade.s, 9_900_000.0, 0.7),
        (SDVXGrade.aaaPlus, 9_800_000.0, 0.6),
        (SDVXGrade.aaa, 9_700_000.0, 0.55),
        (SDVXGrade.aaPlus, 9_500_000.0, 0.45),
        (SDVXGrade.aa, 9_300_000.0, 0.4)
    ].map { grade, value, opacity in
        ScoreHistoryThreshold(label: grade.rawValue, value: value,
                              color: SDVXGrade.color(for: grade.rawValue), opacity: opacity)
    }

    @ViewBuilder
    private func header() -> some View {
        VStack(alignment: .center, spacing: 8.0) {
            Text(verbatim: title)
                .font(.title)
                .fontWeight(.heavy)
                .fontWidth(.compressed)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 8.0)
        .padding(.bottom, 8.0)
        .padding([.leading, .trailing], 20.0)
    }

    @ViewBuilder
    private func difficultySwitcher() -> some View {
        let segments: [DifficultySegmentedPicker<SDVXDifficulty>.Segment] = songRecords.map { record in
            DifficultySegmentedPicker<SDVXDifficulty>.Segment(
                tag: record.difficultyEnum,
                number: record.level,
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
            if songRecord.gradeEnum != .none, songRecord.gradeEnum != .unknown {
                Text(verbatim: songRecord.grade)
                    .sdvxGradeText(outlineWidth: 0.6)
            }
            Spacer()
            Text(songRecord.highScore, format: .number)
                .font(.scoreline(.title))
                .sdvxScoreText(outlineWidth: 0.6)
        }
        .font(.title)
        .fontWidth(.expanded)
        .fontWeight(.black)
    }

    @ViewBuilder
    func chartActions() -> some View {
        HStack(spacing: 0.0) {
            Button {
                openYouTube()
            } label: {
                chartActionLabel(image: Image(.listIconYouTube), label: "YouTube")
            }
            .buttonStyle(.plain)
            if let sdvxInChart {
                Divider()
                Button {
                    navigationManager.push(SDVXScoresPath.chartViewer(chart: sdvxInChart))
                } label: {
                    chartActionLabel(image: Image(.listIconSdvxIn),
                                     label: "Scores.SDVX.ViewChart")
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func chartActionLabel(image: Image, label: LocalizedStringKey) -> some View {
        VStack(spacing: 8.0) {
            image
                .resizable()
                .scaledToFit()
                .frame(width: 26.0, height: 26.0)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }

    func openYouTube() {
        let searchQuery = "SDVX \(difficulty.abbreviation) \(songRecord.title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://youtube.com/results?search_query=\(searchQuery)") {
            openURL(url)
        }
    }
}

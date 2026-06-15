import SwiftUI

struct SDVXScoreViewer: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.openURL) var openURL

    var songRecords: [SDVXSongRecord]
    var initialDifficulty: SDVXDifficulty

    @State private var selectedDifficulty: SDVXDifficulty = .unknown
    @State private var sdvxInChart: SDVXInChart?

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
                headline()
                VStack(alignment: .leading, spacing: 8.0) {
                    SDVXDetailRow("CLEAR TYPE",
                                  value: songRecord.clearTypeEnum.abbreviation,
                                  style: songRecord.clearTypeEnum.color)
                    SDVXDetailRow("GRADE", value: songRecord.grade, style: gradeStyle)
                    SDVXDetailRow("HIGH SCORE", value: songRecord.highScore, style: scoreStyle)
                    SDVXDetailRow("EX SCORE", value: songRecord.exScore, style: scoreStyle)
                }
                HStack(spacing: 0.0) {
                    SDVXNoteTypeDetailRow("PLAYS", value: songRecord.playCount, style: Color.secondary)
                    SDVXNoteTypeDetailRow("CLEARS", value: songRecord.clearCount, style: Color.green)
                    SDVXNoteTypeDetailRow("UC", value: songRecord.ultimateChainCount, style: Color.pink)
                    SDVXNoteTypeDetailRow("PERFECT", value: songRecord.perfectCount, style: Color.yellow)
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                chartActions()
            } header: {
                HStack(spacing: 4.0) {
                    Text(verbatim: difficulty.abbreviation)
                        .foregroundStyle(difficulty.color)
                        .fontWeight(.black)
                    Text(verbatim: songRecord.level)
                        .monospacedDigit()
                    Spacer()
                }
                .fontWidth(.condensed)
            }
        }
        .navigator("ViewTitle.Scores.Song", group: true, inline: true)
        .scrollContentBackground(.hidden)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Spacer()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0.0) {
            TabBarAccessory(placement: .top) {
                VStack(alignment: .center, spacing: 8.0) {
                    Text(verbatim: title)
                        .font(.title)
                        .fontWeight(.heavy)
                        .fontWidth(.compressed)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                    difficultySwitcher()
                }
                .frame(maxWidth: .infinity)
                .padding([.bottom], 8.0)
                .padding([.leading, .trailing], 20.0)
            }
        }
        .conditionalBottomTabBarAccessory()
        .onAppear {
            if selectedDifficulty == .unknown {
                selectedDifficulty = songRecords.contains(where: { $0.difficultyEnum == initialDifficulty })
                    ? initialDifficulty
                    : (songRecords.first?.difficultyEnum ?? .unknown)
            }
        }
        .task(id: selectedDifficulty) {
            sdvxInChart = await fetcher.sdvxInChart(title: songRecord.title, difficulty: difficulty)
        }
    }

    @ViewBuilder
    private func difficultySwitcher() -> some View {
        let segments: [DifficultySegmentedPicker<SDVXDifficulty>.Segment] = songRecords.map { record in
            DifficultySegmentedPicker<SDVXDifficulty>.Segment(
                tag: record.difficultyEnum,
                number: record.level,
                name: Text(verbatim: record.difficultyEnum.abbreviation),
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
                    .foregroundStyle(gradeStyle)
            }
            Spacer()
            Text(songRecord.highScore, format: .number)
                .foregroundStyle(scoreStyle)
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

    var scoreStyle: any ShapeStyle {
        LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
    }

    var gradeStyle: any ShapeStyle {
        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
    }

    func openYouTube() {
        let searchQuery = "SDVX \(difficulty.abbreviation) \(songRecord.title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://youtube.com/results?search_query=\(searchQuery)") {
            openURL(url)
        }
    }
}

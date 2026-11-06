import SwiftUI

struct CapturedPlayScoreView: View {

    var store: IIDXSessionStore
    var play: IIDXCapturedPlay
    var history: [IIDXCapturedPlay] = []

    @State private var matchedSong: IIDXSong?
    @State private var matchedNoteCount: Int?
    @State private var matchedRecord: IIDXSongRecord?
    @State private var chartRadarData: ChartRadarData?
    @State private var hasLoadedSongInfo: Bool = false
    @State private var textageDestination: TextageDestination?

    private let reader = IIDXReader()

    private var score: IIDXLevelScore { play.levelScore() }

    private var displayTitle: String {
        if let songTitle = play.songTitle, !songTitle.isEmpty { return songTitle }
        if let matchedSong { return matchedSong.title }
        return String(localized: "Sessions.UnknownSong")
    }

    private var chartTitle: String? {
        guard play.level != .unknown else { return nil }
        if let matchedSong { return matchedSong.title }
        if let songTitle = play.songTitle, !songTitle.isEmpty { return songTitle }
        return nil
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
                scoreContent()
            }

            if !history.isEmpty {
                Section("Sessions.Score.History") {
                    CapturedPlayHistoryChart(plays: history + [play], noteCount: matchedNoteCount)
                        .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                    ForEach(history) { pastPlay in
                        NavigationLink {
                            CapturedPlayScoreView(store: store, play: pastPlay)
                        } label: {
                            historyRow(pastPlay)
                        }
                    }
                }
            }

            if hasLoadedSongInfo, let chartTitle {
                IIDXChartInfoSections(
                    songTitle: chartTitle,
                    level: play.level,
                    playType: play.playType,
                    chartRadarData: chartRadarData
                ) { legacyURL, chartViewerURL in
                    textageDestination = TextageDestination(legacyURL: legacyURL, chartViewerURL: chartViewerURL)
                }
            }
        }
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background {
            AppBackgroundGradient()
        }
        .navigationTitle("Sessions.Detail.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CapturedPlayDetailView(store: store, play: play)
                } label: {
                    Text("Shared.Edit")
                }
            }
        }
        .toolbar(.hidden, for: .bottomBar)
        .navigationDestination(item: $textageDestination) { destination in
            TextageViewer(legacyURL: destination.legacyURL, chartViewerURL: destination.chartViewerURL)
        }
        .task(id: play.id) { await loadSongInfo() }
    }

    private func loadSongInfo() async {
        let title = play.songTitle ?? ""
        guard !title.isEmpty else { return }
        let song = await reader.matchBEMANIWikiSong(title: title, playType: play.playType)
        let noteCount = song.flatMap { song in
            (play.playType == .single ? song.spNoteCount : song.dpNoteCount)?.noteCount(for: play.level)
        }
        let resolvedTitle = song?.title ?? title
        let records = await reader.songRecordsForSong(title: resolvedTitle)
        matchedSong = song
        matchedNoteCount = noteCount
        matchedRecord = records.first { $0.playType == play.playType } ?? records.first
        chartRadarData = await radarData(title: resolvedTitle)
        hasLoadedSongInfo = true
    }

    private func radarData(title: String) async -> ChartRadarData? {
        let difficulties: [IIDXLevel: Int] = [.beginner: 0, .normal: 1, .hyper: 2, .another: 3, .leggendaria: 4]
        guard let difficulty = difficulties[play.level] else { return nil }
        return await reader.fetchChartRadarData(title: title, playType: play.playType, difficulty: difficulty)
    }

    @ViewBuilder
    private func header() -> some View {
        VStack(alignment: .center, spacing: 8.0) {
            VStack(alignment: .center, spacing: 8.0) {
                IIDXSongTitleBlock(
                    genre: matchedRecord?.genre,
                    title: displayTitle,
                    artist: matchedRecord?.artist,
                    version: matchedRecord?.version,
                    isLeggendaria: play.level == .leggendaria
                )
                difficultyChip()
            }
            .frame(maxWidth: .infinity)
            Divider()
            Text(play.captureDate, format: .dateTime.year().month().day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8.0)
        .padding(.bottom, 8.0)
        .padding([.leading, .trailing], 20.0)
    }

    @ViewBuilder
    private func difficultyChip() -> some View {
        HStack(spacing: 6.0) {
            if play.level != .unknown {
                Text(LocalizedStringKey(play.level.rawValue))
            }
            if play.difficulty > 0 {
                Text(verbatim: "\(play.difficulty)")
            }
            Text(verbatim: play.playType.displayName())
        }
        .font(.caption)
        .fontWeight(.heavy)
        .fontWidth(.expanded)
        .foregroundStyle(.white)
        .padding(.horizontal, 12.0)
        .padding(.vertical, 5.0)
        .background(levelColor, in: Capsule())
    }

    @ViewBuilder
    private func scoreContent() -> some View {
        if score.djLevelEnum() != .none {
            HStack {
                Group {
                    Text(score.djLevel)
                        .foregroundStyle(IIDXDJLevel.style(for: score.djLevel))
                        .strokeText(color: .black, width: 0.6)
                    Spacer()
                    if let scoreRate {
                        Text(scoreRate, format: .percent.precision(.fractionLength(1)))
                            .foregroundStyle(LinearGradient(
                                colors: [.primary.opacity(0.35), .primary.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    }
                }
                .font(.largeTitle)
                .fontWidth(.expanded)
                .fontWeight(.black)
            }
            detailRows()
            noteBreakdown()
        } else {
            detailRows()
            noteBreakdown()
        }
    }

    @ViewBuilder
    private func detailRows() -> some View {
        VStack(alignment: .leading, spacing: 8.0) {
            IIDXClearTypeDetailRow("CLEAR TYPE", value: score.clearType)
            IIDXDetailRow("SCORE", value: score.score, style: Color.iidxScore,
                          outlineColor: .iidxScoreOutline, outlineWidth: 0.3)
            if let matchedNoteCount {
                IIDXDetailRow("NOTES", value: matchedNoteCount, style: Color.secondary)
            }
            if let time = matchedSong?.time, !time.isEmpty {
                IIDXDetailRow("LENGTH", value: time, style: Color.secondary)
            }
        }
    }

    private var scoreRate: Float? {
        guard let matchedNoteCount, matchedNoteCount > 0 else { return nil }
        return Float(score.score) / Float(matchedNoteCount * 2)
    }

    @ViewBuilder
    private func noteBreakdown() -> some View {
        IIDXJudgmentBreakdown(entries: [
            (.perfectGreat, play.perfectGreat),
            (.great, play.great),
            (.good, play.good),
            (.bad, play.bad),
            (.poor, play.poor)
        ])
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    private func historyRow(_ play: IIDXCapturedPlay) -> some View {
        HStack(alignment: .center, spacing: 8.0) {
            VStack(alignment: .leading, spacing: 2.0) {
                Text(play.captureDate, format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline)
                HStack(spacing: 6.0) {
                    IIDXMetallicText.clearType(play.clearType, label: IIDXClearType.abbreviation(for: play.clearType))
                        .font(.caption)
                    Text(verbatim: play.djLevel)
                        .font(.caption.weight(.black))
                        .fontWidth(.expanded)
                        .foregroundStyle(IIDXDJLevel.style(for: play.djLevel))
                        .strokeText(color: .black, width: 0.3)
                }
            }
            Spacer(minLength: 0.0)
            Text(verbatim: "\(play.exScore)")
                .font(.body.monospacedDigit().weight(.heavy))
                .fontWidth(.expanded)
                .foregroundStyle(Color.iidxScore)
                .strokeText(color: .iidxScoreOutline, width: 0.4)
        }
    }

    private var levelColor: Color {
        switch play.level {
        case .beginner: .green
        case .normal: .blue
        case .hyper: .orange
        case .another: .red
        case .leggendaria: .purple
        default: .accent
        }
    }
}

private struct TextageDestination: Hashable {
    let legacyURL: URL?
    let chartViewerURL: URL?
}

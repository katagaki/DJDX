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
            .sectionStyle()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                scoreContent()
            }
            .clearSection()

            if !history.isEmpty {
                TitledSection("Sessions.Score.History", isClear: true) {
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
        .listStyle(.plain)
        .listSectionSpacing(0.0)
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
        HStack(spacing: 8.0) {
            if play.level != .unknown, play.difficulty > 0 {
                LevelBadge(name: String(localized: String.LocalizationValue(play.level.rawValue)),
                           level: String(play.difficulty), tint: levelColor, layout: .horizontal)
            } else if play.difficulty > 0 {
                LevelNumberBadge(level: String(play.difficulty), isCompact: false)
            }
            IIDXPlayTypeBadge(playType: play.playType, size: 13.0)
        }
    }

    @ViewBuilder
    private func scoreContent() -> some View {
        if score.djLevelEnum() != .none {
            IIDXCompactResultSummary(djLevel: score.djLevel, clearType: score.clearType,
                                     score: score.score, scoreRate: scoreRate)
        } else {
            IIDXClearTypeDetailRow("CLEAR TYPE", value: score.clearType)
            IIDXDetailRow("SCORE", score: score.score)
        }
        IIDXCompactJudgments(entries: [
            (.perfectGreat, play.perfectGreat),
            (.great, play.great),
            (.good, play.good),
            (.bad, play.bad),
            (.poor, play.poor)
        ])
        if let matchedNoteCount {
            IIDXDetailRow("NOTES", value: matchedNoteCount, style: Color.secondary)
        }
        if let time = matchedSong?.time, !time.isEmpty {
            IIDXDetailRow("LENGTH", value: time, style: Color.secondary)
        }
    }


    private var scoreRate: Float? {
        guard let matchedNoteCount, matchedNoteCount > 0 else { return nil }
        return Float(score.score) / Float(matchedNoteCount * 2)
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
            IIDXScoreText(play.exScore, style: .body)
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

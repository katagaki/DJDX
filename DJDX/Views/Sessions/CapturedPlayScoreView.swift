import SwiftUI

struct CapturedPlayScoreView: View {

    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    var store: IIDXSessionStore
    var play: IIDXCapturedPlay

    @State private var matchedSong: IIDXSong?
    @State private var matchedNoteCount: Int?

    private let reader = IIDXReader()

    private var score: IIDXLevelScore { play.levelScore() }

    private var displayTitle: String {
        if let songTitle = play.songTitle, !songTitle.isEmpty { return songTitle }
        if let matchedSong { return matchedSong.title }
        return String(localized: "Sessions.UnknownSong")
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
        }
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
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
        .task(id: play.id) { await loadSongInfo() }
    }

    private func loadSongInfo() async {
        let title = play.songTitle ?? ""
        guard !title.isEmpty else { return }
        let song = await reader.matchBEMANIWikiSong(title: title, playType: play.playType)
        let noteCount = song.flatMap { song in
            (play.playType == .single ? song.spNoteCount : song.dpNoteCount)?.noteCount(for: play.level)
        }
        matchedSong = song
        matchedNoteCount = noteCount
    }

    @ViewBuilder
    private func header() -> some View {
        VStack(alignment: .center, spacing: 8.0) {
            VStack(alignment: .center, spacing: 8.0) {
                Text(verbatim: displayTitle)
                    .font(.title)
                    .fontWeight(.heavy)
                    .fontWidth(.compressed)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .textSelection(.enabled)
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
                    switch colorScheme {
                    case .light:
                        Text(score.djLevel)
                            .foregroundStyle(IIDXDJLevel.style(for: score.djLevel, colorScheme: colorScheme))
                            .conditionalShadow(.blue.opacity(0.2), radius: 3.0)
                    case .dark:
                        Text(score.djLevel)
                            .foregroundStyle(IIDXDJLevel.style(for: score.djLevel, colorScheme: colorScheme))
                            .drawingGroup()
                            .shadow(color: .cyan, radius: 5.0)
                    @unknown default:
                        Text(score.djLevel)
                    }
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
            IIDXClearTypeDetailRow("CLEAR TYPE", value: score.clearType, style: clearTypeStyle())
            IIDXDetailRow("SCORE", value: score.score, style: scoreStyle())
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
        HStack(spacing: 0.0) {
            IIDXNoteTypeDetailRow("P-GREAT", value: play.perfectGreat, style: Color.cyan)
            IIDXNoteTypeDetailRow("GREAT", value: play.great, style: Color.yellow)
            IIDXNoteTypeDetailRow("GOOD", value: play.good, style: Color.green)
            IIDXNoteTypeDetailRow("BAD", value: play.bad, style: Color.orange)
            IIDXNoteTypeDetailRow("POOR", value: play.poor, style: Color.red)
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    private func clearTypeStyle() -> any ShapeStyle {
        IIDXClearType.style(for: score.clearType, colorScheme: colorScheme)
    }

    private func scoreStyle() -> any ShapeStyle {
        LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
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

import SwiftUI

struct SessionScoreDataSection: View {
    var store: IIDXSessionStore
    var plays: [IIDXCapturedPlay]
    var playHistories: [String: [IIDXCapturedPlay]]
    var songCompactTitles: [String: IIDXSong]
    var isSearching: Bool
    @Binding var isExpanded: Bool

    @Namespace private var scoresNamespace

    var body: some View {
        VStack(spacing: 0.0) {
            if !isSearching {
                AnalyticsSectionHeader(
                    title: "Analytics.Section.ScoreData",
                    isCollapsible: true,
                    isExpanded: isExpanded
                ) {
                    withAnimation(.smooth.speed(2.0)) { isExpanded.toggle() }
                }
                .padding(.bottom, 12.0)
            }
            if isExpanded || isSearching {
                if plays.isEmpty {
                    Text(isSearching ? "Shared.NoData" : "Sessions.Empty.Title")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24.0)
                } else {
                    Divider()
                    ForEach(plays) { play in
                        NavigationLink {
                            scoreDestination(for: play)
                        } label: {
                            IIDXScoreRow(
                                namespace: scoresNamespace,
                                songRecord: play.asSongRecord(),
                                level: play.level == .unknown ? .another : play.level,
                                score: play.levelScore(),
                                scoreRate: play.scoreRate(songCompactTitles: songCompactTitles)
                            )
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scoreDestination(for play: IIDXCapturedPlay) -> some View {
        let history = Array(playHistories[play.chartKey()]?.dropFirst() ?? [])
        if play.hasConfidentResult {
            CapturedPlayScoreView(store: store, play: play, history: history)
        } else {
            CapturedPlayDetailView(store: store, play: play)
        }
    }
}

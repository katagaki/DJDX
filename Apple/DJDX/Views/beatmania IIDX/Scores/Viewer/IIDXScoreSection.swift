import SwiftUI

struct IIDXScoreSection: View {

    @EnvironmentObject var navigationManager: NavigationManager

    var songTitle: String
    var score: IIDXLevelScore
    var noteCount: Int?
    var playType: IIDXPlayType
    var chartRadarData: ChartRadarData?

    @State private var scoreHistory: [Date: Int] = [:]

    private let fetcher = IIDXReader()

    var body: some View {
        scoreSection()
            .task {
                if score.djLevelEnum() != .none {
                    await reloadScoreHistory()
                }
            }
        IIDXChartInfoSections(
            songTitle: songTitle,
            level: score.level,
            playType: playType,
            chartRadarData: chartRadarData
        ) { legacyURL, chartViewerURL in
            navigationManager.push(ScoresPath.textageViewer(legacyURL: legacyURL,
                                                            chartViewerURL: chartViewerURL))
        }
    }

    @ViewBuilder
    func scoreSection() -> some View {
        Section {
            if score.djLevelEnum() != .none {
                HStack {
                    Group {
                        Text(score.djLevel)
                            .foregroundStyle(IIDXDJLevel.style(for: score.djLevel))
                            .strokeText(color: .black, width: 0.6)
                        Spacer()
                        if let noteCount {
                            Text(Float(score.score) / Float(noteCount * 2),
                                 format: .percent.precision(.fractionLength(1)))
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
                VStack(alignment: .leading, spacing: 8.0) {
                    IIDXClearTypeDetailRow("CLEAR TYPE", value: score.clearType)
                    IIDXDetailRow("SCORE", value: score.score, style: Color.iidxScore,
                                  outlineColor: .iidxScoreOutline, outlineWidth: 0.3)
                }
                IIDXJudgmentBreakdown(entries: score.perfectGreatCount + score.greatCount > 0 ? [
                    (.perfectGreat, score.perfectGreatCount),
                    (.great, score.greatCount),
                    (.miss, score.missCount)
                ] : [
                    (.miss, score.missCount)
                ])
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            } else {
                Text("Scores.Viewer.NoDataForCurrentVersion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if score.clearType != "NO PLAY" {
                    IIDXClearTypeDetailRow("CLEAR TYPE", value: score.clearType)
                }
            }
            if score.djLevelEnum() != .none {
                ScoreHistoryRows(history: scoreHistory, yDomain: historyYDomain, thresholds: historyThresholds)
            }
        }
    }

    private var historyYDomain: ClosedRange<Double> {
        if let noteCount, noteCount > 0 {
            return 0...Double(noteCount * 2)
        }
        return 0...Double(max(scoreHistory.values.max() ?? 1, 1))
    }

    private var historyThresholds: [ScoreHistoryThreshold] {
        guard let noteCount, noteCount > 0 else { return [] }
        let maxScore = Double(noteCount * 2)
        return [
            ScoreHistoryThreshold(label: "AAA", value: maxScore * 8.0 / 9.0, color: .orange, opacity: 0.7),
            ScoreHistoryThreshold(label: "AA", value: maxScore * 7.0 / 9.0, color: .gray, opacity: 0.55),
            ScoreHistoryThreshold(label: "A", value: maxScore * 6.0 / 9.0, color: .teal, opacity: 0.4)
        ]
    }

    func reloadScoreHistory() async {
        // Get list of scores for this song
        let songRecordsForSong = await fetcher.songRecordsForSong(title: songTitle)

        // Get import groups for mapping dates
        let allImportGroups = await fetcher.allImportGroups()
        var importGroupDates: [String: Date] = [:]
        for group in allImportGroups {
            importGroupDates[group.id] = group.importDate
        }

        // Get import group IDs for this song's records
        let importGroupIDs = await fetcher.songRecordImportGroupIDs(for: songTitle)

        var recordImportGroups: [(IIDXSongRecord, String)] = []
        for (index, record) in songRecordsForSong.enumerated() where index < importGroupIDs.count {
            recordImportGroups.append((record, importGroupIDs[index]))
        }

        // Dictionarize list of scores
        scoreHistory = recordImportGroups.reduce(into: [:] as [Date: Int], { partialResult, pair in
            let (songRecord, groupID) = pair
            if let importDate = importGroupDates[groupID],
               let levelScore = songRecord.score(for: score.level), levelScore.score > 0 {
                partialResult[importDate] = levelScore.score
            }
        })
    }
}

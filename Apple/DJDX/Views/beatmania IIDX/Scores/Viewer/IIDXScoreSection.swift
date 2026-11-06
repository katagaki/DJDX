import Charts
import SwiftUI

struct IIDXScoreSection: View {

    @EnvironmentObject var navigationManager: NavigationManager

    var songTitle: String
    var score: IIDXLevelScore
    var noteCount: Int?
    var playType: IIDXPlayType
    var chartRadarData: ChartRadarData?

    @State private var isShowingHistory: Bool = false
    @State private var scoreHistory: [Date: Int] = [:]
    @State private var earliestDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    @State private var latestDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now)!

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
                    IIDXDetailRow("MISS COUNT", value: score.missCount, style: Color.iidxScore,
                                  outlineColor: .iidxScoreOutline, outlineWidth: 0.3)
                }
                IIDXJudgmentBreakdown(entries: [
                    (.perfectGreat, score.perfectGreatCount),
                    (.great, score.greatCount),
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
            if score.djLevelEnum() != .none, scoreHistory.count >= 2 {
                historyRow()
            }
        }
    }

    @ViewBuilder
    func historyRow() -> some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                isShowingHistory.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                Text("Scores.Viewer.ShowHistory")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isShowingHistory ? 90.0 : 0.0))
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        if isShowingHistory {
            historyChart()
                .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
        }
    }

    @ViewBuilder
    // swiftlint:disable:next function_body_length
    func historyChart() -> some View {
        Chart {
            ForEach(scoreHistory.sorted(by: { $0.key < $1.key }), id: \.key) { date, score in
                AreaMark(x: .value("Shared.Date", date), y: .value("Shared.Score", score))
            }
            if let noteCount, noteCount > 0 {
                RuleMark(y: .value("AAA", Float(noteCount * 2) * 8.0 / 9.0))
                    .foregroundStyle(.orange)
                    .annotation(position: .topLeading,
                                overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                        Text(verbatim: "AAA")
                            .foregroundStyle(.orange.gradient)
                            .font(.caption2)
                            .opacity(0.7)
                    }
                    .opacity(0.7)
                RuleMark(y: .value("AA", Float(noteCount * 2) * 7.0 / 9.0))
                    .foregroundStyle(.gray)
                    .annotation(position: .topLeading,
                                overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                        Text(verbatim: "AA")
                            .foregroundStyle(.gray.gradient)
                            .font(.caption2)
                            .opacity(0.55)
                    }
                    .opacity(0.55)
                RuleMark(y: .value("A", Float(noteCount * 2) * 6.0 / 9.0))
                    .foregroundStyle(.teal)
                    .annotation(position: .topLeading,
                                overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                        Text(verbatim: "A")
                            .foregroundStyle(.teal.gradient)
                            .font(.caption2)
                            .opacity(0.4)
                    }
                    .opacity(0.4)
            }
        }
        .chartXScale(domain: earliestDate...latestDate)
        .chartYScale(domain: 0...chartYUpperBound)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisTick()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.year(.twoDigits).month(.abbreviated))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200.0)
    }

    private var chartYUpperBound: Int {
        if let noteCount, noteCount > 0 {
            return noteCount * 2
        }
        return max(scoreHistory.values.max() ?? 1, 1)
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

        // Set date range for chart
        var newEarliestDate: Date = .now
        var newLatestDate: Date = .now
        for pair in recordImportGroups {
            let (songRecord, groupID) = pair
            if let levelScore = songRecord.score(for: score.level), levelScore.score > 0,
               let importDate = importGroupDates[groupID] {
                if importDate < newEarliestDate {
                    newEarliestDate = importDate
                } else if importDate > newLatestDate {
                    newLatestDate = importDate
                }
            }
        }
        earliestDate = Calendar.current.date(byAdding: .day, value: -1, to: newEarliestDate)!
        latestDate = Calendar.current.date(byAdding: .day, value: 1, to: newLatestDate)!
    }
}

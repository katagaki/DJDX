import Charts
import Komponents
import SwiftUI

struct IIDXScoreSection: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.openURL) var openURL
    @EnvironmentObject var navigationManager: NavigationManager

    var songTitle: String
    var score: IIDXLevelScore
    var noteCount: Int?
    var playType: IIDXPlayType
    var chartRadarData: ChartRadarData?

    @State private var isShowingRadarValues: Bool = false

    @State private var isShowingHistory: Bool = false
    @State private var scoreHistory: [Date: Int] = [:]
    @State private var earliestDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    @State private var latestDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now)!

    @State private var textageChart: TextageChart?

    private let fetcher = IIDXReader()

    var body: some View {
        Section {
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
                    IIDXClearTypeDetailRow("CLEAR TYPE", value: score.clearType, style: clearTypeStyle())
                    IIDXDetailRow("SCORE", value: score.score, style: scoreStyle())
                    IIDXDetailRow("MISS COUNT", value: score.missCount, style: scoreStyle())
                }
                HStack(spacing: 0.0) {
                    IIDXNoteTypeDetailRow("P-GREAT", value: score.perfectGreatCount, style: Color.cyan)
                    IIDXNoteTypeDetailRow("GREAT", value: score.greatCount, style: Color.yellow)
                    IIDXNoteTypeDetailRow("MISS", value: score.missCount, style: Color.red)
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            } else {
                Text("Scores.Viewer.NoDataForCurrentVersion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if score.clearType != "NO PLAY" {
                    IIDXClearTypeDetailRow("CLEAR TYPE", value: score.clearType, style: clearTypeStyle())
                }
            }
            if score.djLevelEnum() != .none, scoreHistory.count >= 2 {
                historyRow()
            }
            if let chartRadarData {
                Button {
                    isShowingRadarValues.toggle()
                } label: {
                    Group {
                        if isShowingRadarValues {
                            VStack(spacing: 4.0) {
                                ForEach(chartRadarData.radarData.displayPoints(), id: \.label) { point in
                                    HStack {
                                        Text(verbatim: point.label)
                                            .font(.system(size: 12, weight: .bold))
                                            .fontWidth(.expanded)
                                            .foregroundStyle(point.color)
                                        Spacer()
                                        Text(verbatim: String(format: "%.2f", point.value))
                                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding(.vertical, 4.0)
                        } else {
                            RadarChartView(chartRadarData.radarData)
                                .frame(height: 200.0)
                                .padding(.vertical, 4.0)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            chartActions()
        } header: {
            HStack(spacing: 16.0) {
                IIDXLevelLabel(orientation: .horizontal, levelType: score.level, score: score)
                Spacer()
            }
        }
        .task {
            if score.djLevelEnum() != .none {
                await reloadScoreHistory()
            }
            if score.level != .beginner {
                textageChart = await fetcher.textageChart(title: songTitle)
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

    @ViewBuilder
    func chartActions() -> some View {
        HStack(spacing: 0.0) {
            Button {
                openYouTube()
            } label: {
                chartActionLabel(image: Image(.listIconYouTube), label: "YouTube")
            }
            .buttonStyle(.plain)
            if let textageChart, score.level != .beginner {
                switch playType {
                case .single:
                    textageButton(chart: textageChart, playSide: .side1P,
                                  image: Image(.listIconTextage),
                                  label: "Scores.Viewer.OpenTextage.1P")
                    textageButton(chart: textageChart, playSide: .side2P,
                                  image: Image(.listIconTextageFlipped),
                                  label: "Scores.Viewer.OpenTextage.2P")
                case .double:
                    textageButton(chart: textageChart, playSide: .notApplicable,
                                  image: Image(.listIconTextage),
                                  label: "Scores.Viewer.OpenTextage.DP")
                }
            }
        }
    }

    @ViewBuilder
    func textageButton(chart: TextageChart,
                       playSide: IIDXPlaySide,
                       image: Image,
                       label: LocalizedStringKey) -> some View {
        if let url = chart.pageURL(for: score.level, playType: playType, playSide: playSide) {
            Divider()
            Button {
                navigationManager.push(ScoresPath.textageViewer(url: url))
            } label: {
                chartActionLabel(image: image, label: label)
            }
            .buttonStyle(.plain)
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

    func clearTypeStyle() -> any ShapeStyle {
        IIDXClearType.style(for: score.clearType, colorScheme: colorScheme)
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

        // Build a lookup of song record to import group ID
        // Since records are returned in order, match by index
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

    func openYouTube() {
        switch playType {
        case .single:
            let searchQuery: String = "IIDX SP\(score.level.code()) \(songTitle)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            openURL(URL(string: "https://youtube.com/results?search_query=\(searchQuery)")!)
        case .double:
            let searchQuery: String = "IIDX DP\(score.level.code()) \(songTitle)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            openURL(URL(string: "https://youtube.com/results?search_query=\(searchQuery)")!)
        }
    }

    func scoreStyle() -> any ShapeStyle {
        return LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
    }
}

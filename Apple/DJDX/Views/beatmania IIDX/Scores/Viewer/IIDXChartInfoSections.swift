import Komponents
import SwiftUI

struct IIDXChartInfoSections: View {

    @Environment(\.openURL) var openURL

    var songTitle: String
    var level: IIDXLevel
    var playType: IIDXPlayType
    var chartRadarData: ChartRadarData?
    var onOpenTextage: (URL?, URL?) -> Void

    @State private var isShowingRadarValues: Bool = false
    @State private var textageChart: TextageChart?
    @State private var textageChartViewerChart: TextageChartViewerChart?
    @State private var chartTraits: [IIDXChartTrait]?

    @AppStorage(wrappedValue: false, "ExternalData.TextageChartViewer.Enabled") var isTextageChartViewerEnabled: Bool

    private let fetcher = IIDXReader()

    var body: some View {
        chartSection()
        referenceSection()
    }

    private func loadChartInfo() async {
        guard level != .beginner else { return }
        textageChart = await fetcher.textageChart(title: songTitle)
        textageChartViewerChart = await fetcher.textageChartViewerChart(title: songTitle)
        await reloadChartTraits()
    }

    @ViewBuilder
    func chartSection() -> some View {
        if isChartTraitsAvailable || chartRadarData != nil {
            Section {
                if isChartTraitsAvailable {
                    IIDXChartTraitRow(traits: chartTraits)
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
            } header: {
                ListSectionHeader(text: "Scores.Viewer.Section.Chart")
                    .font(.body)
            }
        }
    }

    @ViewBuilder
    func referenceSection() -> some View {
        Section {
            chartActions()
        } header: {
            ListSectionHeader(text: "Scores.Viewer.Section.Reference")
                .font(.body)
        }
        .task(id: songTitle) {
            await loadChartInfo()
        }
    }

    private var isChartTraitsAvailable: Bool {
        isTextageChartViewerEnabled && level != .beginner && textageChartViewerChart?.textageScoreURL(
            for: level, playType: playType
        ) != nil
    }

    func reloadChartTraits() async {
        guard isChartTraitsAvailable, let textageChartViewerChart else { return }
        let profile = await IIDXChartAnalyzer.shared.profile(for: textageChartViewerChart,
                                                             difficulty: level,
                                                             playType: playType)
        chartTraits = profile?.traits ?? []
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
            if level != .beginner, textageChart != nil || textageChartViewerChart != nil {
                switch playType {
                case .single:
                    textageButton(playSide: .side1P,
                                  image: Image(.listIconTextage),
                                  label: "Scores.Viewer.OpenTextage.1P")
                    textageButton(playSide: .side2P,
                                  image: Image(.listIconTextageFlipped),
                                  label: "Scores.Viewer.OpenTextage.2P")
                case .double:
                    textageButton(playSide: .notApplicable,
                                  image: Image(.listIconTextage),
                                  label: "Scores.Viewer.OpenTextage.DP")
                }
            }
        }
    }

    @ViewBuilder
    func textageButton(playSide: IIDXPlaySide,
                       image: Image,
                       label: LocalizedStringKey) -> some View {
        let legacyURL = textageChart?.pageURL(for: level, playType: playType, playSide: playSide)
        let chartViewerURL = textageChartViewerChart?.pageURL(for: level, playType: playType)
        if legacyURL != nil || chartViewerURL != nil {
            Divider()
            Button {
                onOpenTextage(legacyURL, chartViewerURL)
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

    func openYouTube() {
        switch playType {
        case .single:
            let searchQuery: String = "IIDX SP\(level.code()) \(songTitle)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            openURL(URL(string: "https://youtube.com/results?search_query=\(searchQuery)")!)
        case .double:
            let searchQuery: String = "IIDX DP\(level.code()) \(songTitle)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            openURL(URL(string: "https://youtube.com/results?search_query=\(searchQuery)")!)
        }
    }
}

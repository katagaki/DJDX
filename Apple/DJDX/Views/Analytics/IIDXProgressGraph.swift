import Charts
import SwiftUI

enum IIDXProgressGraphStyle: String, CaseIterable, Identifiable {
    case bars
    case stacked

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .bars: "Analytics.Progress.Style.Bars"
        case .stacked: "Analytics.Progress.Style.Stacked"
        }
    }

    var systemImage: String {
        switch self {
        case .bars: "chart.bar.xaxis"
        case .stacked: "chart.line.uptrend.xyaxis"
        }
    }
}

enum IIDXProgressKind: String, Hashable {
    case clears
    case highScores

    var series: [String] {
        switch self {
        case .clears:
            IIDXClearType.ascending
                .filter { $0 != .noPlay && $0 != .failed }
                .reversed()
                .map(\.rawValue)
        case .highScores:
            IIDXDJLevel.sortedStrings.reversed()
        }
    }

    var defaultVisibleSeries: Set<String> {
        switch self {
        case .clears: [IIDXClearType.clear.rawValue, IIDXClearType.easyClear.rawValue]
        case .highScores: [IIDXDJLevel.djAAA.rawValue, IIDXDJLevel.djAA.rawValue, IIDXDJLevel.djA.rawValue]
        }
    }

    var defaultHiddenSeries: Set<String> {
        Set(series).subtracting(defaultVisibleSeries)
    }

    var cardType: AnalyticsCardType {
        switch self {
        case .clears: .progressTrend
        case .highScores: .scoreProgressTrend
        }
    }

    var transitionID: String {
        switch self {
        case .clears: "Progress"
        case .highScores: "ScoreProgress"
        }
    }

    var hiddenSeriesKey: String {
        switch self {
        case .clears: "Analytics.Progress.HiddenSeries"
        case .highScores: "Analytics.ScoreProgress.HiddenSeries"
        }
    }

    var styleKey: String {
        switch self {
        case .clears: "Analytics.Progress.Style"
        case .highScores: "Analytics.ScoreProgress.Style"
        }
    }

    func label(for series: String) -> String {
        switch self {
        case .clears: IIDXClearType.abbreviation(for: series)
        case .highScores: series
        }
    }

    func color(for series: String) -> Color {
        switch self {
        case .clears: IIDXClearType.color(for: series)
        case .highScores: IIDXDJLevel.color(for: series)
        }
    }

    func metallicLabel(for series: String) -> IIDXMetallicText {
        switch self {
        case .clears: .clearType(series, label: label(for: series))
        case .highScores: .djLevel(series)
        }
    }

    func color(for series: String, phase: Double) -> Color {
        if self == .clears && series == IIDXClearType.fullComboClear.rawValue {
            return FullComboRainbow.color(phase: phase)
        }
        return color(for: series)
    }
}

struct IIDXProgressMark: Identifiable {
    let series: String
    let seriesIndex: Int
    let index: Int
    let date: Date
    let stackStart: Int
    let stackTotal: Int
    let count: Int

    var id: String { "\(series)\u{1}\(date.timeIntervalSince1970)" }
}

struct IIDXProgressGraph: View {
    let points: [IIDXProgressPoint]
    let kind: IIDXProgressKind
    var scrollsBars: Bool

    @AppStorage var hiddenSeries: Set<String>
    @AppStorage var style: IIDXProgressGraphStyle
    @State var scrollPosition: Double = 0.0

    init(points: [IIDXProgressPoint], kind: IIDXProgressKind, scrollsBars: Bool = false) {
        self.points = points
        self.kind = kind
        self.scrollsBars = scrollsBars
        _hiddenSeries = AppStorage(wrappedValue: kind.defaultHiddenSeries, kind.hiddenSeriesKey)
        _style = AppStorage(wrappedValue: .stacked, kind.styleKey)
    }

    var visibleImportCount: Int {
        scrollsBars && style == .bars ? min(points.count, 6) : points.count
    }

    var visibleSeries: [String] {
        kind.series.filter { !hiddenSeries.contains($0) }
    }

    var hasFullCombo: Bool {
        kind == .clears && visibleSeries.contains(IIDXClearType.fullComboClear.rawValue)
    }

    var marks: [IIDXProgressMark] {
        points.enumerated().flatMap { index, point in
            var stackStart = 0
            let stackTotal = visibleSeries.reduce(0) { $0 + point.count(for: $1, kind: kind) }
            return visibleSeries.enumerated().map { seriesIndex, series in
                let count = point.count(for: series, kind: kind)
                defer { stackStart += count }
                return IIDXProgressMark(
                    series: series, seriesIndex: seriesIndex, index: index,
                    date: point.date, stackStart: stackStart, stackTotal: stackTotal, count: count
                )
            }
        }
    }

    var groupHalfWidth: Double {
        style == .stacked ? 0.3 : 0.4
    }

    var labeledIndices: [Int] {
        let step = max(1, Int((Double(visibleImportCount) / 4.0).rounded(.up)))
        return Array(stride(from: points.count - 1, through: 0, by: -step))
    }

    var initialScrollPosition: Double {
        Double(max(points.count - visibleImportCount, 0)) - 0.5
    }

    var body: some View {
        FullComboRainbowTimeline(isActive: hasFullCombo) { phase in
            Chart(marks) { mark in
                seriesMark(mark)
            }
            .chartXScale(domain: -0.5...(Double(points.count) - 0.5))
            .chartXAxis {
                AxisMarks(values: labeledIndices.map { Double($0) - groupHalfWidth }) { value in
                    if let position = value.as(Double.self),
                       case let index = Int((position + groupHalfWidth).rounded()),
                       points.indices.contains(index) {
                        AxisValueLabel {
                            Text(points[index].date, format: .dateTime.month().day())
                        }
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: visibleSeries.map { kind.label(for: $0) },
                range: visibleSeries.map { kind.color(for: $0, phase: phase) }
            )
            .chartScrollableAxes(visibleImportCount < points.count ? .horizontal : [])
            .chartXVisibleDomain(length: max(visibleImportCount, 1))
            .chartScrollPosition(x: $scrollPosition)
            .onAppear {
                scrollPosition = initialScrollPosition
            }
            .onChange(of: visibleImportCount) {
                scrollPosition = initialScrollPosition
            }
        }
    }

    @ChartContentBuilder
    func seriesMark(_ mark: IIDXProgressMark) -> some ChartContent {
        let series = kind.label(for: mark.series)
        let groupStart = Double(mark.index) - groupHalfWidth
        if style == .stacked {
            let groupEnd = groupStart + groupHalfWidth * 2.0
            RectangleMark(
                xStart: .value("Shared.Date", groupStart),
                xEnd: .value("Shared.Date", groupEnd),
                yStart: .value("Shared.ClearCount", mark.stackStart),
                yEnd: .value("Shared.ClearCount", mark.stackStart + mark.count)
            )
            .foregroundStyle(by: .value("Analytics.Progress", series))
            .mask {
                topRoundedMask(xStart: groupStart, xEnd: groupEnd, height: mark.stackTotal)
            }
        } else {
            let barWidth = groupHalfWidth * 2.0 / Double(max(visibleSeries.count, 1))
            let barStart = groupStart + barWidth * Double(mark.seriesIndex)
            RectangleMark(
                xStart: .value("Shared.Date", barStart),
                xEnd: .value("Shared.Date", barStart + barWidth),
                yStart: .value("Shared.ClearCount", 0),
                yEnd: .value("Shared.ClearCount", mark.count)
            )
            .foregroundStyle(by: .value("Analytics.Progress", series))
            .mask {
                topRoundedMask(xStart: barStart, xEnd: barStart + barWidth, height: mark.count)
            }
        }
    }

    @ChartContentBuilder
    func topRoundedMask(xStart: Double, xEnd: Double, height: Int) -> some ChartContent {
        RectangleMark(
            xStart: .value("Shared.Date", xStart),
            xEnd: .value("Shared.Date", xEnd),
            yStart: .value("Shared.ClearCount", 0),
            yEnd: .value("Shared.ClearCount", height)
        )
        .cornerRadius(2.0)
        RectangleMark(
            xStart: .value("Shared.Date", xStart),
            xEnd: .value("Shared.Date", xEnd),
            yStart: .value("Shared.ClearCount", 0),
            yEnd: .value("Shared.ClearCount", Double(height) / 2.0)
        )
    }
}

struct IIDXProgressDetailView: View {
    let points: [IIDXProgressPoint]
    let kind: IIDXProgressKind

    @AppStorage var hiddenSeries: Set<String>
    @AppStorage var style: IIDXProgressGraphStyle

    init(points: [IIDXProgressPoint], kind: IIDXProgressKind) {
        self.points = points
        self.kind = kind
        _hiddenSeries = AppStorage(wrappedValue: kind.defaultHiddenSeries, kind.hiddenSeriesKey)
        _style = AppStorage(wrappedValue: .stacked, kind.styleKey)
    }

    var visibleSeries: [String] {
        kind.series.filter { !hiddenSeries.contains($0) }
    }

    var body: some View {
        List {
            if points.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    IIDXProgressGraph(points: points, kind: kind, scrollsBars: true)
                        .chartLegend(position: .bottom, alignment: .leading) {
                            legend
                        }
                        .frame(height: 240.0)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(points.reversed()) { point in
                        VStack(alignment: .leading, spacing: 6.0) {
                            Text(point.date, format: .dateTime.year().month().day())
                                .font(.subheadline.weight(.semibold))
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 96.0), spacing: 10.0, alignment: .leading)],
                                alignment: .leading,
                                spacing: 4.0
                            ) {
                                ForEach(visibleSeries, id: \.self) { series in
                                    seriesCount(series, count: point.count(for: series, kind: kind))
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.smooth.speed(2.0), value: hiddenSeries)
        .animation(.smooth.speed(2.0), value: style)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                customizationMenu
            }
        }
    }

    var customizationMenu: some View {
        Menu {
            Section("Analytics.Progress.Style") {
                Picker(selection: $style) {
                    ForEach(IIDXProgressGraphStyle.allCases) { style in
                        Label(style.titleKey, systemImage: style.systemImage)
                            .tag(style)
                    }
                } label: {
                    Text("Analytics.Progress.Style")
                }
                .pickerStyle(.inline)
            }
            Section("Analytics.Progress.Series") {
                ForEach(kind.series, id: \.self) { series in
                    Toggle(isOn: isShowing(series)) {
                        Text(verbatim: series)
                    }
                }
            }
        } label: {
            Label("Analytics.Progress.Customize", systemImage: "slider.horizontal.3")
        }
        .menuActionDismissBehavior(.disabled)
    }

    func isShowing(_ series: String) -> Binding<Bool> {
        Binding {
            !hiddenSeries.contains(series)
        } set: { isShowing in
            if isShowing {
                hiddenSeries.remove(series)
            } else {
                hiddenSeries.insert(series)
            }
        }
    }

    var legend: some View {
        FlowLayout(horizontalSpacing: 10.0, verticalSpacing: 4.0) {
            ForEach(visibleSeries, id: \.self) { series in
                HStack(spacing: 4.0) {
                    Circle()
                        .fill(kind.color(for: series))
                        .frame(width: 8.0, height: 8.0)
                    kind.metallicLabel(for: series)
                        .font(.caption2)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func seriesCount(_ series: String, count: Int) -> some View {
        HStack(spacing: 3.0) {
            kind.metallicLabel(for: series)
            Text(verbatim: "\(count)")
                .foregroundStyle(count > 0 ? .primary : .secondary)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

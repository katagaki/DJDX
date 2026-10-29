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
}

struct IIDXProgressMark: Identifiable {
    let series: String
    let index: Int
    let date: Date
    let start: Int
    let end: Int

    var id: String { "\(series)\u{1}\(date.timeIntervalSince1970)" }
}

struct IIDXProgressGraph: View {
    let points: [IIDXProgressPoint]
    let kind: IIDXProgressKind
    var usesDateAxis: Bool

    @AppStorage var hiddenSeries: Set<String>
    @AppStorage var style: IIDXProgressGraphStyle

    init(points: [IIDXProgressPoint], kind: IIDXProgressKind, usesDateAxis: Bool = true) {
        self.points = points
        self.kind = kind
        self.usesDateAxis = usesDateAxis
        _hiddenSeries = AppStorage(wrappedValue: kind.defaultHiddenSeries, kind.hiddenSeriesKey)
        _style = AppStorage(wrappedValue: .stacked, kind.styleKey)
    }

    var visibleSeries: [String] {
        kind.series.filter { !hiddenSeries.contains($0) }
    }

    var marks: [IIDXProgressMark] {
        let isStacked = style == .stacked
        return points.enumerated().flatMap { index, point in
            var base = 0
            return visibleSeries.map { series in
                let count = point.count(for: series, kind: kind)
                let start = isStacked ? base : 0
                base += count
                return IIDXProgressMark(
                    series: series, index: index, date: point.date, start: start, end: start + count
                )
            }
        }
    }

    var body: some View {
        Group {
            if usesDateAxis {
                Chart(marks) { mark in
                    seriesMark(mark, xValue: .value("Shared.Date", mark.date, unit: .day))
                }
            } else {
                Chart(marks) { mark in
                    seriesMark(mark, xValue: .value("Shared.Date", mark.index))
                }
            }
        }
        .chartForegroundStyleScale(
            domain: visibleSeries.map { kind.label(for: $0) },
            range: visibleSeries.map { kind.color(for: $0) }
        )
        .chartXScale(range: .plotDimension(startPadding: 8.0, endPadding: 8.0))
    }

    @ChartContentBuilder
    func seriesMark<X: Plottable>(_ mark: IIDXProgressMark, xValue: PlottableValue<X>) -> some ChartContent {
        let series = kind.label(for: mark.series)
        if style == .stacked {
            BarMark(
                x: xValue,
                yStart: .value("Shared.ClearCount", mark.start),
                yEnd: .value("Shared.ClearCount", mark.end)
            )
            .foregroundStyle(by: .value("Analytics.Progress", series))
        } else {
            BarMark(
                x: xValue,
                y: .value("Shared.ClearCount", mark.end)
            )
            .foregroundStyle(by: .value("Analytics.Progress", series))
            .position(by: .value("Analytics.Progress", series))
        }
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
                    IIDXProgressGraph(points: points, kind: kind)
                        .chartLegend(position: .bottom, alignment: .leading)
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

    func seriesCount(_ series: String, count: Int) -> some View {
        HStack(spacing: 3.0) {
            Text(verbatim: kind.label(for: series))
                .foregroundStyle(kind.color(for: series))
                .fontWeight(.heavy)
            Text(verbatim: "\(count)")
                .foregroundStyle(count > 0 ? .primary : .secondary)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

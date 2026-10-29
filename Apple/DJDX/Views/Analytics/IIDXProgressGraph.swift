import Charts
import SwiftUI

enum IIDXProgressGraphStyle: String, CaseIterable, Identifiable {
    case lines
    case stacked

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .lines: "Analytics.Progress.Style.Lines"
        case .stacked: "Analytics.Progress.Style.Stacked"
        }
    }

    var systemImage: String {
        switch self {
        case .lines: "chart.xyaxis.line"
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
    let date: Date
    let start: Int
    let end: Int

    var id: String { "\(series)\u{1}\(date.timeIntervalSince1970)" }
}

struct IIDXProgressGraph: View {
    let points: [IIDXProgressPoint]
    let kind: IIDXProgressKind
    var symbolSize: CGFloat

    @AppStorage var hiddenSeries: Set<String>
    @AppStorage var style: IIDXProgressGraphStyle

    init(points: [IIDXProgressPoint], kind: IIDXProgressKind, symbolSize: CGFloat = 30.0) {
        self.points = points
        self.kind = kind
        self.symbolSize = symbolSize
        _hiddenSeries = AppStorage(wrappedValue: kind.defaultHiddenSeries, kind.hiddenSeriesKey)
        _style = AppStorage(wrappedValue: .stacked, kind.styleKey)
    }

    var visibleSeries: [String] {
        kind.series.filter { !hiddenSeries.contains($0) }
    }

    var marks: [IIDXProgressMark] {
        let isStacked = style == .stacked
        return points.flatMap { point in
            var base = 0
            return visibleSeries.map { series in
                let count = point.count(for: series, kind: kind)
                let start = isStacked ? base : 0
                base += count
                return IIDXProgressMark(series: series, date: point.date, start: start, end: start + count)
            }
        }
    }

    var body: some View {
        Chart(marks) { mark in
            if style == .stacked {
                AreaMark(
                    x: .value("Shared.Date", mark.date),
                    yStart: .value("Shared.ClearCount", mark.start),
                    yEnd: .value("Shared.ClearCount", mark.end),
                    series: .value("Analytics.Progress", kind.label(for: mark.series))
                )
                .foregroundStyle(by: .value("Analytics.Progress", kind.label(for: mark.series)))
            } else {
                LineMark(
                    x: .value("Shared.Date", mark.date),
                    y: .value("Shared.ClearCount", mark.end),
                    series: .value("Analytics.Progress", kind.label(for: mark.series))
                )
                .foregroundStyle(by: .value("Analytics.Progress", kind.label(for: mark.series)))
                .symbol(by: .value("Analytics.Progress", kind.label(for: mark.series)))
                .symbolSize(symbolSize)
            }
        }
        .chartForegroundStyleScale(
            domain: visibleSeries.map { kind.label(for: $0) },
            range: visibleSeries.map { kind.color(for: $0) }
        )
        .chartSymbolScale(
            domain: visibleSeries.map { kind.label(for: $0) },
            range: visibleSeries.map { _ in BasicChartSymbolShape.circle }
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

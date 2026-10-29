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

struct IIDXProgressMark: Identifiable {
    let series: String
    let date: Date
    let start: Int
    let end: Int

    var id: String { "\(series)\u{1}\(date.timeIntervalSince1970)" }
}

struct IIDXProgressGraph: View {
    let points: [IIDXProgressPoint]
    var symbolSize: CGFloat = 30.0

    @AppStorage(wrappedValue: [], "Analytics.Progress.HiddenSeries") var hiddenSeries: Set<String>
    @AppStorage(wrappedValue: .lines, "Analytics.Progress.Style") var style: IIDXProgressGraphStyle

    static let highScoresSeries = "NEW HIGH SCORE"

    static let allSeries: [String] = IIDXClearType.ascending
        .filter { $0 != .noPlay && $0 != .failed }
        .map(\.rawValue) + [highScoresSeries]

    static func color(for series: String) -> Color {
        series == highScoresSeries ? .orange : IIDXClearType.color(for: series)
    }

    static func label(for series: String) -> String {
        series == highScoresSeries ? "HIGH SCORE" : IIDXClearType.abbreviation(for: series)
    }

    var visibleSeries: [String] {
        Self.allSeries.filter { !hiddenSeries.contains($0) }
    }

    var marks: [IIDXProgressMark] {
        let isStacked = style == .stacked
        return points.flatMap { point in
            var base = 0
            return visibleSeries.map { series in
                let count = point.count(for: series)
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
                    series: .value("Analytics.Progress", Self.label(for: mark.series))
                )
                .foregroundStyle(by: .value("Analytics.Progress", Self.label(for: mark.series)))
                .opacity(0.3)
                .interpolationMethod(.monotone)
            }
            LineMark(
                x: .value("Shared.Date", mark.date),
                y: .value("Shared.ClearCount", mark.end),
                series: .value("Analytics.Progress", Self.label(for: mark.series))
            )
            .foregroundStyle(by: .value("Analytics.Progress", Self.label(for: mark.series)))
            .symbol(by: .value("Analytics.Progress", Self.label(for: mark.series)))
            .symbolSize(symbolSize)
            .interpolationMethod(.monotone)
        }
        .chartForegroundStyleScale(
            domain: visibleSeries.map { Self.label(for: $0) },
            range: visibleSeries.map { Self.color(for: $0) }
        )
        .chartSymbolScale(
            domain: visibleSeries.map { Self.label(for: $0) },
            range: visibleSeries.map { _ in BasicChartSymbolShape.circle }
        )
    }
}

struct IIDXProgressDetailView: View {
    let points: [IIDXProgressPoint]

    @AppStorage(wrappedValue: [], "Analytics.Progress.HiddenSeries") var hiddenSeries: Set<String>
    @AppStorage(wrappedValue: .lines, "Analytics.Progress.Style") var style: IIDXProgressGraphStyle

    var visibleClearTypes: [String] {
        IIDXProgressGraph.allSeries.filter {
            $0 != IIDXProgressGraph.highScoresSeries && !hiddenSeries.contains($0)
        }
    }

    var showsHighScores: Bool {
        !hiddenSeries.contains(IIDXProgressGraph.highScoresSeries)
    }

    var body: some View {
        List {
            if points.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    IIDXProgressGraph(points: points)
                        .chartLegend(position: .bottom, alignment: .leading)
                        .frame(height: 240.0)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(points.reversed()) { point in
                        HStack(spacing: 12.0) {
                            Text(point.date, format: .dateTime.year().month().day())
                                .font(.subheadline)
                            Spacer()
                            if !visibleClearTypes.isEmpty {
                                count(
                                    visibleClearTypes.reduce(0) { $0 + point.count(for: $1) },
                                    systemImage: AnalyticsCardType.newClearLamps.systemImage,
                                    color: AnalyticsCardType.newClearLamps.iconColor
                                )
                            }
                            if showsHighScores {
                                count(
                                    point.newHighScores,
                                    systemImage: AnalyticsCardType.newScoreUpdates.systemImage,
                                    color: IIDXProgressGraph.color(for: IIDXProgressGraph.highScoresSeries)
                                )
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
                ForEach(IIDXProgressGraph.allSeries, id: \.self) { series in
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

    func count(_ value: Int, systemImage: String, color: Color) -> some View {
        Label {
            Text(verbatim: "\(value)")
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(value > 0 ? .primary : .secondary)
                .frame(minWidth: 32.0, alignment: .trailing)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
        .labelStyle(.titleAndIcon)
    }
}

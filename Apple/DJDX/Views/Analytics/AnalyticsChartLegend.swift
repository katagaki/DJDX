import SwiftUI

struct AnalyticsChartLegend: View {

    let items: [(label: IIDXMetallicText, color: Color)]

    let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4.0) {
            ForEach(items, id: \.label.text) { item in
                HStack(spacing: 6.0) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8.0, height: 8.0)
                    item.label
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer(minLength: 0.0)
                }
            }
        }
        .padding(.vertical, 2.0)
    }
}

struct ClearTypeLegend: View {
    var body: some View {
        AnalyticsChartLegend(
            items: IIDXClearType.sortedWithoutNoPlay.map {
                (.clearType($0.rawValue), IIDXClearType.color(for: $0.rawValue))
            }
        )
    }
}

struct DJLevelLegend: View {
    var body: some View {
        AnalyticsChartLegend(
            items: IIDXDJLevel.sorted.reversed().map {
                (.djLevel($0.rawValue), IIDXDJLevel.color(for: $0.rawValue))
            }
        )
    }
}

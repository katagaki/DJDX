import SwiftUI

struct StackedBreakdownItem: Identifiable {
    let label: String
    let value: Int
    let style: AnyShapeStyle

    var id: String { label }

    init(label: String, value: Int, color: Color) {
        self.label = label
        self.value = value
        self.style = AnyShapeStyle(color)
    }

    init(label: String, value: Int, style: AnyShapeStyle) {
        self.label = label
        self.value = value
        self.style = style
    }
}

struct StackedBreakdownBar: View {
    let items: [StackedBreakdownItem]

    private var total: Int { items.reduce(0) { $0 + $1.value } }
    private var legend: [StackedBreakdownItem] {
        let top = Set(items.sorted { $0.value > $1.value }.prefix(4).map(\.id))
        return items.filter { top.contains($0.id) }
    }
    private let legendColumns = [
        GridItem(.flexible(), spacing: 8.0),
        GridItem(.flexible(), spacing: 8.0)
    ]

    var body: some View {
        if total == 0 {
            Text("Shared.NoData")
                .emptyLabel()
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 6.0) {
                GeometryReader { geometry in
                    HStack(spacing: 0.0) {
                        ForEach(items) { item in
                            Rectangle()
                                .fill(item.style)
                                .frame(width: geometry.size.width * CGFloat(item.value) / CGFloat(total))
                        }
                    }
                }
                .frame(height: 14.0)
                LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 2.0) {
                    ForEach(legend) { item in
                        HStack(spacing: 3.0) {
                            Rectangle()
                                .fill(item.style)
                                .frame(width: 6.0, height: 6.0)
                            Text(verbatim: item.label)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 2.0)
                            Text(verbatim: "\(item.value)")
                                .font(.scoreline(size: 8.0))
                                .fontWidth(.standard)
                                .fixedSize()
                        }
                        .font(.system(size: 10.0, weight: .bold))
                        .frame(height: 12.0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct CountTile: View {
    let count: Int
    let title: Text
    let railColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2.0) {
            Text(verbatim: "\(count)")
                .font(.scoreline(size: 20.0))
                .fontWidth(.standard)
                .foregroundStyle(count > 0 ? .primary : .secondary)
                .fixedSize()
            title
                .cardLabel()
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.horizontal, DesignMetrics.cardPadding)
        .padding(.vertical, 4.0)
        .cardBackground()
        .environment(\.cardRailColor, railColor)
    }
}

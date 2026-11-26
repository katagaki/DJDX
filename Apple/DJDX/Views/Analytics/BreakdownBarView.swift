import SwiftUI

struct BreakdownBarItem: Identifiable {
    var id: String { label }
    let label: String
    let count: Int
    let color: Color
    var metallicLabel: IIDXMetallicText?
    var isFullCombo: Bool = false
}

struct BreakdownBarView: View {
    var items: [BreakdownBarItem]

    var body: some View {
        VStack(spacing: 12.0) {
            bar
            legend
        }
    }

    private var bar: some View {
        let total = max(1, items.reduce(0) { $0 + $1.count })
        return GeometryReader { proxy in
            HStack(spacing: 0.0) {
                ForEach(items) { item in
                    Group {
                        if item.isFullCombo {
                            FullComboRainbowFill()
                        } else {
                            item.color
                        }
                    }
                    .frame(width: proxy.size.width * CGFloat(item.count) / CGFloat(total))
                }
            }
        }
        .frame(height: 18.0)
        .clipShape(Capsule())
    }

    private var legend: some View {
        FlowLayout(horizontalSpacing: 12.0, verticalSpacing: 6.0) {
            ForEach(items) { item in
                HStack(spacing: 4.0) {
                    if let metallicLabel = item.metallicLabel {
                        metallicLabel
                    } else {
                        RoundedRectangle(cornerRadius: 2.0)
                            .fill(item.color)
                            .frame(width: 10.0, height: 10.0)
                        Text(verbatim: item.label)
                            .foregroundStyle(.secondary)
                    }
                    Text(verbatim: "\(item.count)")
                        .font(.scoreline(.caption, weight: .bold))
                        .fontWidth(.standard)
                        .foregroundStyle(.primary)
                }
                .font(.caption)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

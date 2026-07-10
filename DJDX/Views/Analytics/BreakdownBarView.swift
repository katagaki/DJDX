import SwiftUI

struct BreakdownBarItem: Identifiable {
    var id: String { label }
    let label: String
    let count: Int
    let color: Color
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
                    Rectangle()
                        .fill(item.color)
                        .frame(width: proxy.size.width * CGFloat(item.count) / CGFloat(total))
                }
            }
        }
        .frame(height: 18.0)
        .clipShape(Capsule())
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96.0), spacing: 8.0)],
            alignment: .leading,
            spacing: 6.0
        ) {
            ForEach(items) { item in
                HStack(spacing: 5.0) {
                    RoundedRectangle(cornerRadius: 2.0)
                        .fill(item.color)
                        .frame(width: 10.0, height: 10.0)
                    Text(verbatim: item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2.0)
                    Text(verbatim: "\(item.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
        }
    }
}

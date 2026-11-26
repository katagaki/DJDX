import SwiftUI

struct TierListRow<Label: View>: View {

    let tier: TierListTier?
    let charts: [TierListChart]
    let onPlace: (String, TierListTier?, String?) -> Void
    @ViewBuilder let label: () -> Label

    @State var isTargeted: Bool = false
    @State var targetedChartID: String?
    @State var dropCount: Int = 0
    @State var assigningChartID: String?

    var isHighlighted: Bool { isTargeted || targetedChartID != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 0.0) {
            label()
            FlowLayout(horizontalSpacing: 6.0, verticalSpacing: 6.0) {
                ForEach(charts) { chart in
                    tile(for: chart)
                        .dropDestination(for: String.self) { ids, _ in
                            for id in ids where id != chart.id {
                                onPlace(id, tier, chart.id)
                            }
                            dropCount += 1
                            return true
                        } isTargeted: { targeted in
                            if targeted {
                                targetedChartID = chart.id
                            } else if targetedChartID == chart.id {
                                targetedChartID = nil
                            }
                        }
                }
            }
            .padding(6.0)
            .frame(maxWidth: .infinity, minHeight: 60.0, alignment: .topLeading)
        }
        .background(isHighlighted ? Color.accentColor.opacity(0.2) : Color.clear)
        .background(Color.tierListBackground)
        .dropDestination(for: String.self) { ids, _ in
            for id in ids {
                onPlace(id, tier, nil)
            }
            dropCount += 1
            return true
        } isTargeted: { isTargeted = $0 }
        .sensoryFeedback(.selection, trigger: isHighlighted) { _, newValue in newValue }
        .sensoryFeedback(.impact(weight: .medium), trigger: dropCount)
    }

    @ViewBuilder
    func tile(for chart: TierListChart) -> some View {
        if tier == nil {
            draggableTile(for: chart)
                .onTapGesture {
                    assigningChartID = chart.id
                }
                .popover(isPresented: Binding(
                    get: { assigningChartID == chart.id },
                    set: { if !$0, assigningChartID == chart.id { assigningChartID = nil } }
                )) {
                    tierPicker(for: chart)
                        .presentationCompactAdaptation(.popover)
                }
        } else {
            draggableTile(for: chart)
        }
    }

    func tierPicker(for chart: TierListChart) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40.0), spacing: 8.0), count: 4), spacing: 8.0) {
            ForEach(TierListTier.allCases) { target in
                Button {
                    assigningChartID = nil
                    onPlace(chart.id, target, nil)
                    dropCount += 1
                } label: {
                    Text(target.rawValue)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: 40.0, height: 40.0)
                        .background(target.color, in: .rect(cornerRadius: 8.0))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16.0)
    }

    func draggableTile(for chart: TierListChart) -> some View {
        TierListTile(chart: chart)
            .contentShape(.dragPreview, .rect)
            .draggable(chart.id) {
                TierListTile(chart: chart)
            }
    }
}

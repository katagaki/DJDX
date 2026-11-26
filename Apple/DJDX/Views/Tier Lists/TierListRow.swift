import SwiftUI

struct TierListRow<Label: View>: View {

    let tier: TierListTier?
    let charts: [TierListChart]
    let onPlace: (String, TierListTier?, String?) -> Void
    @ViewBuilder let label: () -> Label

    @State var isTargeted: Bool = false
    @State var targetedChartID: String?
    @State var dropCount: Int = 0

    var isHighlighted: Bool { isTargeted || targetedChartID != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 0.0) {
            label()
            FlowLayout(horizontalSpacing: 6.0, verticalSpacing: 6.0) {
                ForEach(charts) { chart in
                    TierListTile(chart: chart)
                        .contentShape(.dragPreview, .rect)
                        .draggable(chart.id) {
                            TierListTile(chart: chart)
                        }
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
}

import SwiftUI

struct TierListRow<Label: View>: View {

    let tier: TierListTier?
    let charts: [TierListChart]
    let onPlace: (String, TierListTier?, String?) -> Void
    @ViewBuilder let label: () -> Label

    @State var isTargeted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 0.0) {
            label()
            FlowLayout(horizontalSpacing: 4.0, verticalSpacing: 4.0) {
                ForEach(charts) { chart in
                    TierListTile(chart: chart)
                        .draggable(chart.id) {
                            TierListTile(chart: chart)
                        }
                        .dropDestination(for: String.self) { ids, _ in
                            for id in ids where id != chart.id {
                                onPlace(id, tier, chart.id)
                            }
                            return true
                        }
                        .contextMenu {
                            ForEach(TierListTier.allCases) { target in
                                Button("TierList.MoveTo.\(target.rawValue)") {
                                    onPlace(chart.id, target, nil)
                                }
                                .disabled(target == tier)
                            }
                            if tier != nil {
                                Button("TierList.Unplace", systemImage: "arrow.uturn.down") {
                                    onPlace(chart.id, nil, nil)
                                }
                            }
                        }
                }
            }
            .padding(4.0)
            .frame(maxWidth: .infinity, minHeight: 60.0, alignment: .topLeading)
        }
        .background(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
        .background(.background.tertiary)
        .clipShape(.rect(cornerRadius: 8.0))
        .dropDestination(for: String.self) { ids, _ in
            for id in ids {
                onPlace(id, tier, nil)
            }
            return true
        } isTargeted: { isTargeted = $0 }
    }
}

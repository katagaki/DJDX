import SwiftUI

struct IIDXChartTraitRow: View {

    var traits: [IIDXChartTrait]?

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text("Scores.Viewer.Characteristics")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if let traits {
                if traits.isEmpty {
                    Text("Scores.Viewer.ChartType.None")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(horizontalSpacing: 14.0, verticalSpacing: 8.0) {
                        ForEach(traits, id: \.self) { trait in
                            traitTag(trait)
                        }
                    }
                }
            } else {
                HStack(spacing: 8.0) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scores.Viewer.ChartType.Analyzing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2.0)
    }

    @ViewBuilder
    private func traitTag(_ trait: IIDXChartTrait) -> some View {
        HStack(spacing: 6.0) {
            IIDXChartTraitIcon(trait: trait)
            Text(trait.localizedName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fixedSize()
        }
    }
}

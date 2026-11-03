import SwiftUI

struct IIDXChartTraitRow: View {

    var traits: [IIDXChartTrait]?

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text(verbatim: "CHART TYPE")
                .font(.caption)
                .fontWidth(.expanded)
                .fontWeight(.heavy)
                .foregroundStyle(.secondary)
            if let traits {
                if traits.isEmpty {
                    Text("Scores.Viewer.ChartType.None")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(horizontalSpacing: 6.0, verticalSpacing: 6.0) {
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
        Label {
            Text(trait.localizedName)
        } icon: {
            Image(systemName: trait.systemImage)
        }
        .font(.caption)
        .fontWeight(.bold)
        .foregroundStyle(trait.color)
        .padding(.horizontal, 10.0)
        .padding(.vertical, 5.0)
        .background(trait.color.opacity(0.15), in: Capsule())
    }
}

extension IIDXChartTrait {
    var localizedName: LocalizedStringKey {
        switch self {
        case .backloaded: "Scores.Viewer.ChartType.Backloaded"
        case .burst: "Scores.Viewer.ChartType.Burst"
        case .stamina: "Scores.Viewer.ChartType.Stamina"
        case .chaotic: "Scores.Viewer.ChartType.Chaotic"
        case .scratch: "Scores.Viewer.ChartType.Scratch"
        case .charge: "Scores.Viewer.ChartType.Charge"
        case .soflan: "Scores.Viewer.ChartType.Soflan"
        }
    }

    var systemImage: String {
        switch self {
        case .backloaded: "chart.line.uptrend.xyaxis"
        case .burst: "bolt.fill"
        case .stamina: "flame.fill"
        case .chaotic: "shuffle"
        case .scratch: "record.circle"
        case .charge: "rectangle.portrait.fill"
        case .soflan: "speedometer"
        }
    }

    var color: Color {
        switch self {
        case .backloaded: .orange
        case .burst: .yellow
        case .stamina: .pink
        case .chaotic: .green
        case .scratch: .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255)
        case .charge: .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255)
        case .soflan: .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255)
        }
    }
}

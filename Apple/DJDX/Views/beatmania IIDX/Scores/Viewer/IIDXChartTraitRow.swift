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

struct IIDXChartTraitIcon: View {

    var trait: IIDXChartTrait
    var size: CGFloat = 26.0

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [trait.color.mix(with: .white, by: 0.15), trait.color],
                                 startPoint: .top, endPoint: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(.black.opacity(0.18), lineWidth: 0.5)
            }
            .overlay {
                Image(systemName: trait.systemImage)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 0.5, y: 0.5)
            }
            .frame(width: size, height: size)
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
        case .scratch: "opticaldisc.fill"
        case .charge: "capsule.portrait.fill"
        case .soflan: "gauge.with.dots.needle.67percent"
        }
    }

    var color: Color {
        switch self {
        case .backloaded: .orange
        case .burst: .init(red: 230 / 255, green: 175 / 255, blue: 0 / 255)
        case .stamina: .pink
        case .chaotic: .init(red: 52 / 255, green: 178 / 255, blue: 89 / 255)
        case .scratch: .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255)
        case .charge: .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255)
        case .soflan: .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255)
        }
    }
}

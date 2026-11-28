import SwiftUI

struct TierListImage: View {

    static let labelWidth: CGFloat = 80.0
    static let tileSpacing: CGFloat = 6.0
    static let rowPadding: CGFloat = 6.0
    static let outerPadding: CGFloat = 16.0
    static let targetAspectRatio: CGFloat = 4.0 / 3.0

    let title: String
    let columns: Int
    let chartsInTier: (TierListTier) -> [TierListChart]

    static func width(columns: Int) -> CGFloat {
        let tiles = CGFloat(columns) * TierListTile.width + CGFloat(max(columns - 1, 0)) * tileSpacing
        return labelWidth + tiles + rowPadding * 2.0 + outerPadding * 2.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            HStack(alignment: .firstTextBaseline) {
                Text("TierList.Title")
                Spacer(minLength: 8.0)
                Text(verbatim: title)
                    .foregroundStyle(.secondary)
            }
            .font(.title3)
            .fontWeight(.bold)
            .padding(.horizontal, 4.0)
            VStack(spacing: 2.0) {
                ForEach(TierListTier.allCases) { tier in
                    HStack(alignment: .top, spacing: 0.0) {
                        Text(tier.rawValue)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.black.opacity(0.85))
                            .frame(width: Self.labelWidth)
                            .frame(maxHeight: .infinity)
                            .background(tier.color)
                        FlowLayout(horizontalSpacing: Self.tileSpacing, verticalSpacing: Self.tileSpacing) {
                            ForEach(chartsInTier(tier)) { chart in
                                TierListTile(chart: chart)
                            }
                        }
                        .padding(Self.rowPadding)
                        .frame(maxWidth: .infinity, minHeight: 60.0, alignment: .topLeading)
                        .background(Color.tierListBackground)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2.0)
            .background(.black)
        }
        .padding(Self.outerPadding)
        .frame(width: Self.width(columns: columns))
        .background(Color.tierListBackground)
        .environment(\.colorScheme, .dark)
    }

    @MainActor
    static func render(title: String, chartsInTier: @escaping (TierListTier) -> [TierListChart]) -> UIImage? {
        var best: (columns: Int, difference: CGFloat)?
        for columns in 4...24 {
            let renderer = ImageRenderer(
                content: TierListImage(title: title, columns: columns, chartsInTier: chartsInTier)
            )
            renderer.scale = 1.0
            guard let size = renderer.uiImage?.size, size.height > 0.0 else { continue }
            let aspectRatio = size.width / size.height
            let difference = abs(aspectRatio - targetAspectRatio)
            if difference < (best?.difference ?? .infinity) {
                best = (columns, difference)
            }
            if aspectRatio >= targetAspectRatio { break }
        }
        guard let best else { return nil }
        let renderer = ImageRenderer(
            content: TierListImage(title: title, columns: best.columns, chartsInTier: chartsInTier)
        )
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

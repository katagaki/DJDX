import SwiftUI

struct TierListTile: View {

    let chart: TierListChart

    static let width: CGFloat = 104.0

    var body: some View {
        HStack(spacing: 0.0) {
            Rectangle()
                .fill(chart.lampColor)
                .frame(width: 5.0)
            VStack(alignment: .leading, spacing: 2.0) {
                Text(chart.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4.0) {
                    Text(chart.difficultyLabel)
                        .foregroundStyle(chart.difficultyColor)
                    Spacer(minLength: 0.0)
                    if !chart.grade.isEmpty {
                        Text(chart.grade)
                            .foregroundStyle(chart.gradeColor)
                    }
                }
                .font(.system(size: 10.0, weight: .heavy))
                .lineLimit(1)
            }
            .padding(.horizontal, 6.0)
            .padding(.vertical, 4.0)
        }
        .frame(width: Self.width, alignment: .leading)
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 6.0))
        .overlay {
            RoundedRectangle(cornerRadius: 6.0)
                .stroke(chart.lampColor.opacity(0.5), lineWidth: 1.0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(chart.lampLabel)
    }
}

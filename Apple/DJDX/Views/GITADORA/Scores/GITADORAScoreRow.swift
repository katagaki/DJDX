import SwiftUI

struct GITADORAScoreRow: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var record: GITADORASongRecord

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            record.clearTypeEnum.color
                .frame(width: 10.0)
                .frame(maxHeight: .infinity)
                .conditionalShadow(.black.opacity(0.2), radius: 1.0, x: 2.0)

            VStack(alignment: .leading, spacing: 2.0) {
                Text(record.title)
                    .bold()
                    .squashedHorizontally()
                HStack(alignment: .center, spacing: 6.0) {
                    if !record.achievementRate.isEmpty {
                        Text(verbatim: "\(record.achievementRate)%")
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                            startPoint: .top, endPoint: .bottom))
                            .fontWidth(.expanded)
                            .fontWeight(.heavy)
                    }
                    if record.rankEnum != .none && record.rankEnum != .unknown {
                        Divider().frame(maxHeight: 14.0)
                        Text(verbatim: record.rank)
                            .foregroundStyle(record.rankEnum.style(colorScheme: colorScheme))
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                    }
                    Divider().frame(maxHeight: 14.0)
                    Text(verbatim: record.clearTypeEnum.abbreviation)
                        .foregroundStyle(record.clearTypeEnum.color)
                        .fontWidth(.expanded)
                        .fontWeight(.bold)
                    if record.skillValue > 0 {
                        Divider().frame(maxHeight: 14.0)
                        Text(verbatim: String(format: "%.2f", record.skillValue))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    if record.score > 0 {
                        Divider().frame(maxHeight: 14.0)
                        Text(record.score.formatted(.number))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .font(.caption)
            }
            .padding([.top, .bottom], 8.0)

            Spacer(minLength: 0.0)

            LevelBadge(name: record.difficultyEnum.rawValue, level: record.level.isEmpty ? "-" : record.level,
                       tint: record.difficultyEnum.color, layout: .horizontal)
                .padding([.top, .bottom], 8.0)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }
}

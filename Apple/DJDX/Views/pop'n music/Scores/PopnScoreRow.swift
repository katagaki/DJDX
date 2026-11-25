import SwiftUI

struct PopnScoreRow: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var record: PopnSongRecord

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            record.clearType.color
                .frame(width: 10.0)
                .frame(maxHeight: .infinity)
                .conditionalShadow(.black.opacity(0.2), radius: 1.0, x: 2.0)

            VStack(alignment: .leading, spacing: 2.0) {
                if !record.genre.isEmpty {
                    Text(record.genre)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(record.title)
                    .bold()
                    .squashedHorizontally()
                HStack(alignment: .center, spacing: 6.0) {
                    Text(record.score.formatted(.number))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                        startPoint: .top, endPoint: .bottom))
                        .fontWidth(.expanded)
                        .fontWeight(.heavy)
                        .monospacedDigit()
                    if record.rankEnum != .none {
                        Divider().frame(maxHeight: 14.0)
                        Text(verbatim: record.rank)
                            .foregroundStyle(record.rankEnum.style(colorScheme: colorScheme))
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                    }
                    Divider().frame(maxHeight: 14.0)
                    Text(verbatim: record.medalEnum.abbreviation)
                        .foregroundStyle(record.clearType.color)
                        .fontWidth(.expanded)
                        .fontWeight(.bold)
                }
                .font(.caption)
            }
            .padding([.top, .bottom], 8.0)

            Spacer(minLength: 0.0)

            VStack(spacing: 1.0) {
                Text(verbatim: record.level > 0 ? "\(record.level)" : "-")
                    .font(.system(size: 18.0).weight(.heavy))
                    .monospacedDigit()
                Text(verbatim: record.difficultyEnum.rawValue)
                    .font(.system(size: 10.0).weight(.black))
                    .fontWidth(.condensed)
                    .foregroundStyle(record.difficultyEnum.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding([.top, .bottom], 6.0)
            .frame(width: 78.0, alignment: .center)
            .cardBackground(cornerRadius: 6.0)
            .padding([.top, .bottom], 8.0)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing)
    }
}

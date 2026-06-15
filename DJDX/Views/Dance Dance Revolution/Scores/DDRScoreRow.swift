import SwiftUI

struct DDRScoreRow: View {

    var record: DDRSongRecord

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            record.difficultyEnum.color
                .frame(width: 10.0)
                .frame(maxHeight: .infinity)
                .conditionalShadow(.black.opacity(0.2), radius: 1.0, x: 2.0)

            VStack(alignment: .leading, spacing: 2.0) {
                Text(record.title)
                    .bold()
                    .fontWidth(.condensed)
                    .lineLimit(2)
                HStack(alignment: .center, spacing: 6.0) {
                    if record.score > 0 {
                        Text(String(record.score))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                            startPoint: .top, endPoint: .bottom))
                            .fontWidth(.expanded)
                            .fontWeight(.heavy)
                    }
                    if !record.rankDisplay.isEmpty {
                        Divider().frame(maxHeight: 14.0)
                        Text(record.rankDisplay)
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                            startPoint: .top, endPoint: .bottom))
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                    }
                    if !record.clearDisplay.isEmpty {
                        Divider().frame(maxHeight: 14.0)
                        Text(record.clearDisplay)
                            .foregroundStyle(.secondary)
                            .fontWidth(.expanded)
                            .fontWeight(.bold)
                    }
                }
                .font(.caption)
            }
            .padding([.top, .bottom], 8.0)

            Spacer(minLength: 0.0)

            VStack(spacing: 1.0) {
                Text(verbatim: record.difficultyEnum.abbreviation)
                    .font(.system(size: 10.0).weight(.black))
                    .foregroundStyle(record.difficultyEnum.color)
                Text(verbatim: record.levelText)
                    .font(.system(size: 18.0).weight(.heavy))
                    .fontWidth(.condensed)
                    .monospacedDigit()
            }
            .padding([.top, .bottom], 6.0)
            .frame(width: 78.0, alignment: .center)
            .cardBackground(cornerRadius: 6.0)
            .padding([.top, .bottom], 8.0)
        }
        .frame(maxWidth: .infinity)
        .padding([.trailing], 20.0)
    }
}

//
//  SDVXScoreRow.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI

struct SDVXScoreRow: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var record: SDVXSongRecord

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            // Leading clear-mark lamp
            record.clearTypeEnum.color
                .frame(width: 12.0)
                .frame(maxHeight: .infinity)
                .conditionalShadow(.black.opacity(0.2), radius: 1.0, x: 2.0)

            VStack(alignment: .leading, spacing: 2.0) {
                Text(record.title)
                    .bold()
                    .fontWidth(.condensed)
                    .lineLimit(2)
                HStack(alignment: .center, spacing: 6.0) {
                    if record.gradeEnum != .none && record.gradeEnum != .unknown {
                        Text(verbatim: record.grade)
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                            startPoint: .top, endPoint: .bottom))
                            .fontWidth(.expanded)
                            .fontWeight(.black)
                    }
                    if record.highScore > 0 {
                        Divider().frame(maxHeight: 14.0)
                        Text(String(record.highScore))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                            startPoint: .top, endPoint: .bottom))
                            .fontWidth(.expanded)
                            .fontWeight(.heavy)
                    }
                    Divider().frame(maxHeight: 14.0)
                    Text(verbatim: record.clearTypeEnum.abbreviation)
                        .foregroundStyle(record.clearTypeEnum.color)
                        .fontWidth(.expanded)
                        .fontWeight(.bold)
                }
                .font(.caption)
            }
            .padding([.top, .bottom], 8.0)

            Spacer(minLength: 0.0)

            // Difficulty + level label
            VStack(spacing: 1.0) {
                Text(verbatim: record.difficultyEnum.abbreviation)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(record.difficultyEnum.color)
                Text(verbatim: record.level)
                    .font(.title3.weight(.heavy))
                    .fontWidth(.condensed)
                    .monospacedDigit()
            }
            .padding([.top, .bottom], 6.0)
            .frame(width: 78.0, alignment: .center)
            .background(.thinMaterial)
            .clipShape(.rect(cornerRadius: 6.0))
            .padding([.top, .bottom], 8.0)
        }
        .frame(maxWidth: .infinity)
        .padding([.trailing], 20.0)
    }
}

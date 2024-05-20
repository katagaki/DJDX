//
//  ClearLampOverviewChart.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import SwiftUI

struct ClearLampOverviewChart: View {
    @Binding var clearLampPerDifficulty: [Int: [String: Int]]

    var body: some View {
        Chart(Array(clearLampPerDifficulty.keys), id: \.self) { difficulty in
            ForEach(clearLampPerDifficulty[difficulty]!.sorted(by: <), id: \.key) { clearType, count in
                BarMark(
                    x: .value("LEVEL", difficulty),
                    y: .value("CLEAR COUNT", count),
                    width: .fixed(10.0)
                )
                .foregroundStyle(
                    by: .value("CLEAR TYPE", clearType)
                )
                .position(
                    by: .value("CLEAR TYPE", clearType),
                    axis: .horizontal,
                    span: .ratio(1)
                )
            }
        }
        .chartLegend(.visible)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 13))
        }
        .chartXScale(domain: 1...13)
        .chartForegroundStyleScale([
            "FULLCOMBO CLEAR": .blue,
            "CLEAR": .cyan,
            "ASSIST CLEAR": .purple,
            "EASY CLEAR": .green,
            "HARD CLEAR": .pink,
            "EX HARD CLEAR": .yellow,
            "FAILED": .red
        ])
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if let plotFrame = proxy.plotFrame {
                                    let origin: CGPoint = geometry[plotFrame].origin
                                    let location: CGPoint = CGPoint(
                                        x: value.location.x - origin.x,
                                        y: value.location.y - origin.y
                                    )
                                    let (difficulty, _) = proxy.value(at: location, as: (Int, Int).self) ?? (0, 0)
                                    debugPrint(difficulty)
                                    // TODO: Display floating detail popup for difficulty
                                }
                            }
                    )
            }
        }
    }
}

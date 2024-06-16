//
//  ClearLampOverviewGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import SwiftUI

struct ClearLampOverviewGraph: View {
    @Binding var clearLampPerDifficulty: [Int: [String: Int]]

    @State var isInteractive: Bool = false
    @State var difficultyBelowFinger: Int?

    var body: some View {
        Chart(Array(clearLampPerDifficulty.keys), id: \.self) { difficulty in
            ForEach(clearLampPerDifficulty[difficulty]!.sorted(by: <), id: \.key) { clearType, count in
                BarMark(
                    x: .value("LEVEL", difficulty),
                    y: .value("Shared.ClearCount", count),
                    width: .inset(8.0)
                )
                .foregroundStyle(
                    by: .value("Shared.ClearType", clearType)
                )
                .position(
                    by: .value("Shared.ClearType", clearType),
                    axis: .horizontal,
                    span: .ratio(1)
                )
            }
            .annotation(position: .top) {
                if let difficultyBelowFinger, difficulty == difficultyBelowFinger {
                    let totalPlayedPerDifficulty: Int = clearLampPerDifficulty[difficulty]?
                        .reduce(into: 0) { partialResult, keyValue in
                            partialResult += keyValue.value
                        } ?? 0
                    Text("Shared.SongCount.\(totalPlayedPerDifficulty)")
                        .padding([.top, .bottom], 2.0)
                        .padding([.leading, .trailing], 4.0)
                        .background(Color.accentColor)
                        .foregroundStyle(.text)
                        .clipShape(.capsule(style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 2.0, y: 1.5)
                        .zIndex(-999)
                }
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
            if isInteractive {
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
                                        withAnimation(.snappy.speed(2.0)) {
                                            difficultyBelowFinger = difficulty
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.snappy.speed(2.0)) {
                                        difficultyBelowFinger = nil
                                    }
                                }
                        )
                }
            }
        }
    }
}

//
//  OverviewClearTypeOverallGraph.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/21.
//

import Charts
import OrderedCollections
import SwiftUI

struct OverviewClearTypeOverallGraph: View {
    @Binding var graphData: [Int: OrderedDictionary<String, Int>]

    @State var isInteractive: Bool = false
    @State var difficultyBelowFinger: Int?

    var populatedDifficulties: [Int] {
        graphData.filter { _, counts in
            counts.values.contains(where: { $0 > 0 })
        }.keys.sorted()
    }

    var xDomain: ClosedRange<Int> {
        if isInteractive {
            return 1...13
        }
        guard let first = populatedDifficulties.first,
              let last = populatedDifficulties.last else {
            return 1...13
        }
        if populatedDifficulties.count == 1 {
            // Pad a single data point with its neighbors when in range
            return max(1, first - 1)...min(12, first + 1)
        }
        return first...last
    }

    var body: some View {
        Chart(Array(graphData.keys), id: \.self) { difficulty in
            ForEach(graphData[difficulty]!.keys.reversed(), id: \.self) { clearType in
                let count = graphData[difficulty]![clearType]!
                BarMark(
                    x: .value("LEVEL", difficulty),
                    y: .value("Shared.ClearCount", count),
                    width: .inset(8.0),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Shared.IIDX.ClearType", clearType))
                .zIndex(0)
            }
            .annotation(position: .top) {
                if let difficultyBelowFinger, difficulty == difficultyBelowFinger {
                    let totalPlayedPerDifficulty: Int = graphData[difficulty]?
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
                        .zIndex(999)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 13))
        }
        .chartPlotStyle { plotArea in
            plotArea.padding(.horizontal, isInteractive ? 0.0 : 8.0)
        }
        .chartXScale(domain: xDomain, range: .plotDimension(startPadding: 8.0, endPadding: 8.0))
        .chartForegroundStyleScale([
            "FULLCOMBO CLEAR": .blue,
            "CLEAR": .cyan,
            "EASY CLEAR": .green,
            "ASSIST CLEAR": .purple,
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

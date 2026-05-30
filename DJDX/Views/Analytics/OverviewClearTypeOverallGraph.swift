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

    // Pad the domain by half a unit on each side so the first and last bars
    // sit fully inside the plot instead of overflowing its edges.
    var xDomain: ClosedRange<Double> {
        if isInteractive {
            return 0.5...12.5
        }
        guard let first = populatedDifficulties.first,
              let last = populatedDifficulties.last else {
            return 0.5...12.5
        }
        if populatedDifficulties.count == 1 {
            let lower = max(1, first - 1)
            let upper = min(12, first + 1)
            return (Double(lower) - 0.5)...(Double(upper) + 0.5)
        }
        return (Double(first) - 0.5)...(Double(last) + 0.5)
    }

    // Integer level ticks within the (half-unit padded) domain, so each axis
    // label lines up exactly with its bar.
    var axisValues: [Double] {
        let lower = Int(xDomain.lowerBound.rounded(.up))
        let upper = Int(xDomain.upperBound.rounded(.down))
        guard lower <= upper else { return [] }
        return (lower...upper).map(Double.init)
    }

    var body: some View {
        Chart(graphData.keys.sorted(), id: \.self) { difficulty in
            ForEach(graphData[difficulty]!.keys.reversed(), id: \.self) { clearType in
                let count = graphData[difficulty]![clearType]!
                BarMark(
                    x: .value("LEVEL", Double(difficulty)),
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
            AxisMarks(values: axisValues) { value in
                AxisGridLine()
                AxisTick()
                if let level = value.as(Double.self) {
                    AxisValueLabel { Text(verbatim: "\(Int(level))") }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.padding(.horizontal, isInteractive ? 0.0 : 8.0)
        }
        .chartXScale(domain: xDomain)
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
                                        let levelValue = proxy.value(at: location, as: Double.self) ?? 0.0
                                        withAnimation(.snappy.speed(2.0)) {
                                            difficultyBelowFinger = Int(levelValue.rounded())
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

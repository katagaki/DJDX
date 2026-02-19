//
//  TogglableChartDetailView.swift
//  DJDX
//
//  Created on 2026/02/19.
//

import Charts
import OrderedCollections
import SwiftUI

struct TogglableClearTypeDetailView: View {
    @Binding var graphData: [Int: OrderedDictionary<String, Int>]
    @Binding var difficulty: Int

    @State var showAsPieChart: Bool = true

    var body: some View {
        Group {
            if showAsPieChart {
                OverviewClearTypePerDifficultyGraph(
                    graphData: $graphData,
                    difficulty: $difficulty
                )
                .chartLegend(.visible)
            } else {
                OverviewClearTypeBarGraph(
                    graphData: $graphData,
                    difficulty: $difficulty
                )
                .chartLegend(.visible)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) {
                        showAsPieChart.toggle()
                    }
                } label: {
                    Image(systemName: showAsPieChart
                          ? "chart.bar.fill" : "chart.pie.fill")
                }
            }
        }
    }
}

struct TogglableDJLevelDetailView: View {
    @Binding var graphData: [Int: [IIDXDJLevel: Int]]
    @Binding var difficulty: Int

    @State var showAsPieChart: Bool = false

    var body: some View {
        Group {
            if showAsPieChart {
                OverviewDJLevelPieGraph(
                    graphData: $graphData,
                    difficulty: $difficulty
                )
                .chartLegend(.visible)
            } else {
                OverviewDJLevelPerDifficultyGraph(
                    graphData: $graphData,
                    difficulty: $difficulty
                )
                .chartLegend(.visible)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) {
                        showAsPieChart.toggle()
                    }
                } label: {
                    Image(systemName: showAsPieChart
                          ? "chart.bar.fill" : "chart.pie.fill")
                }
            }
        }
    }
}

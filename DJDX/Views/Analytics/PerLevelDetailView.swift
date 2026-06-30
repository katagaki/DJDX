//
//  PerLevelDetailView.swift
//  DJDX
//
//  Created on 2026/06/04.
//

import Charts
import OrderedCollections
import SwiftUI

// A small titled wrapper for one chart within a per-level detail view.
struct PerLevelDetailSection<Content: View>: View {
    let titleKey: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text(titleKey)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct ClearTypePerLevelDetailView: View {
    @Bindable var model: AnalyticsModel
    let difficulty: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20.0) {
                PerLevelDetailSection(titleKey: "Analytics.PerLevel.Breakdown") {
                    TogglableClearTypeDetailView(
                        graphData: $model.clearTypePerDifficulty,
                        difficulty: .constant(difficulty)
                    )
                    .frame(height: 240.0)
                }
                PerLevelDetailSection(titleKey: "Analytics.PerLevel.Trend") {
                    TrendsClearTypeGraph(
                        graphData: $model.clearTypePerImportGroup,
                        difficulty: .constant(difficulty)
                    )
                    .chartLegend(.hidden)
                    .frame(height: 240.0)
                }
                ClearTypeLegend()
            }
            .padding()
        }
    }
}

struct DJLevelPerLevelDetailView: View {
    @Bindable var model: AnalyticsModel
    let difficulty: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20.0) {
                PerLevelDetailSection(titleKey: "Analytics.PerLevel.Breakdown") {
                    TogglableDJLevelDetailView(
                        graphData: $model.djLevelPerDifficulty,
                        difficulty: .constant(difficulty)
                    )
                    .frame(height: 240.0)
                }
                PerLevelDetailSection(titleKey: "Analytics.PerLevel.Trend") {
                    TrendsDJLevelGraph(
                        graphData: $model.djLevelPerImportGroup,
                        difficulty: .constant(difficulty)
                    )
                    .chartLegend(.hidden)
                    .frame(height: 240.0)
                }
                DJLevelLegend()
            }
            .padding()
        }
    }
}

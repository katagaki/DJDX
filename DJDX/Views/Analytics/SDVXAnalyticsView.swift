//
//  SDVXAnalyticsView.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import Charts
import OrderedCollections
import SwiftUI

struct SDVXAnalyticsView: View {

    @Bindable var model: SDVXAnalyticsModel

    let cardColumns = [
        GridItem(.flexible(), spacing: 12.0),
        GridItem(.flexible(), spacing: 12.0)
    ]

    var body: some View {
        VStack(spacing: 0.0) {
            AnalyticsSectionHeader(title: AnalyticsSection.overview.titleKey)

            LazyVGrid(columns: cardColumns, spacing: 12.0) {
                summaryCard(title: "Analytics.SDVX.Volforce",
                            systemImage: "bolt.fill",
                            iconColor: .orange,
                            value: String(format: "%.2f", model.volforce))
                summaryCard(title: "Analytics.SDVX.TotalCharts",
                            systemImage: "music.note.list",
                            iconColor: .blue,
                            value: String(model.totalCharts))
            }
            .padding(.horizontal)

            AnalyticsSectionHeader(title: "Analytics.SDVX.ClearBreakdown")
            clearBreakdownCard
                .padding(.horizontal)
                .padding(.bottom, 16.0)

            AnalyticsSectionHeader(title: "Analytics.SDVX.GradeBreakdown")
            gradeBreakdownCard
                .padding(.horizontal)
                .padding(.bottom, 16.0)
        }
        .task {
            if model.dataState == .initializing {
                await model.reload()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await model.reload() }
        }
    }

    func summaryCard(title: LocalizedStringKey,
                     systemImage: String,
                     iconColor: Color,
                     value: String) -> some View {
        AnalyticsCardView(title: title, systemImage: systemImage, iconColor: iconColor, contentHeight: 44.0) {
            Text(verbatim: value)
                .font(.title.bold())
                .fontWidth(.expanded)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Aggregate clear-type counts across all difficulty categories
    var totalClearCounts: OrderedDictionary<String, Int> {
        var totals: OrderedDictionary<String, Int> = OrderedDictionary(
            uniqueKeys: SDVXClearType.sortedStringsWithoutNoPlay,
            values: SDVXClearType.sortedStringsWithoutNoPlay.map { _ in 0 }
        )
        for (_, counts) in model.clearTypePerDifficulty {
            for (key, value) in counts {
                totals[key, default: 0] += value
            }
        }
        return totals
    }

    var totalGradeCounts: OrderedDictionary<String, Int> {
        var totals: OrderedDictionary<String, Int> = OrderedDictionary(
            uniqueKeys: SDVXGrade.sortedStrings,
            values: SDVXGrade.sortedStrings.map { _ in 0 }
        )
        for (_, counts) in model.gradePerDifficulty {
            for (key, value) in counts {
                totals[key, default: 0] += value
            }
        }
        return totals
    }

    var clearBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.SDVX.ClearBreakdown",
                          systemImage: "checkmark.seal",
                          iconColor: .green,
                          contentHeight: 200.0) {
            Chart(totalClearCounts.elements.filter { $0.value > 0 }, id: \.key) { element in
                BarMark(
                    x: .value("Shared.ClearCount", element.value),
                    y: .value("Type", clearLabel(element.key))
                )
                .foregroundStyle(SDVXClearType(rawValue: element.key)?.color ?? .gray)
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
        }
    }

    var gradeBreakdownCard: some View {
        AnalyticsCardView(title: "Analytics.SDVX.GradeBreakdown",
                          systemImage: "rosette",
                          iconColor: .yellow,
                          contentHeight: 240.0) {
            Chart(totalGradeCounts.elements.filter { $0.value > 0 }, id: \.key) { element in
                BarMark(
                    x: .value("Shared.ClearCount", element.value),
                    y: .value("Grade", element.key)
                )
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                startPoint: .leading, endPoint: .trailing))
            }
            .chartXAxis { AxisMarks { AxisGridLine() } }
        }
    }

    func clearLabel(_ rawValue: String) -> String {
        SDVXClearType(rawValue: rawValue)?.abbreviation ?? rawValue
    }
}

//
//  AnalyticsDestinationView.swift
//  DJDX
//
//  Created by Claude on 2026/05/29.
//

import Charts
import OrderedCollections
import SwiftUI

struct AnalyticsDestinationView: View {

    @Bindable var model: AnalyticsModel
    let path: AnalyticsPath
    var analyticsNamespace: Namespace.ID

    @AppStorage(wrappedValue: 1, "Analytics.Overview.ClearType.Level") var levelFilterForOverviewClearType: Int
    @AppStorage(wrappedValue: 1, "Analytics.Overview.ScoreRate.Level") var levelFilterForOverviewScoreRate: Int
    @AppStorage(wrappedValue: 1, "Analytics.Trends.ClearType.Level") var levelFilterForTrendsClearType: Int
    @AppStorage(wrappedValue: 1, "Analytics.Trends.DJLevel.Level") var levelFilterForTrendsDJLevel: Int

    func perLevelTitle(_ difficulty: Int, _ category: AnalyticsPerLevelCategory) -> String {
        let separator = NSLocalizedString("Analytics.PerLevel.TitleSeparator", comment: "")
        let categoryTitle = NSLocalizedString(category.titleKey, comment: "")
        return "LEVEL \(difficulty)\(separator)\(categoryTitle)"
    }

    // swiftlint:disable:next function_body_length
    var body: some View {
        Group {
            switch path {
            case .clearTypeOverviewGraph:
                ClearTypeOverviewListView(graphData: $model.clearTypePerDifficulty)
                    .navigationTitle("Analytics.ClearType.Overall")
                    .automaticNavigationTransition(id: "ClearType.Overall", in: analyticsNamespace)
            case .clearTypePerDifficultyGraph:
                VStack {
                    TogglableClearTypeDetailView(
                        graphData: $model.clearTypePerDifficulty,
                        difficulty: $levelFilterForOverviewClearType
                    )
                    ClearTypeLegend()
                        .padding(.horizontal)
                    DifficultyPicker(
                        selection: $levelFilterForOverviewClearType,
                        difficulties: .constant(model.difficulties)
                    )
                }
                .padding(.top)
                .navigationTitle("Analytics.ClearType.ByDifficulty")
                .automaticNavigationTransition(id: "ClearType.ByDifficulty", in: analyticsNamespace)
            case .scoreRatePerDifficultyGraph:
                VStack {
                    TogglableDJLevelDetailView(
                        graphData: $model.djLevelPerDifficulty,
                        difficulty: $levelFilterForOverviewScoreRate
                    )
                    DJLevelLegend()
                        .padding(.horizontal)
                    DifficultyPicker(
                        selection: $levelFilterForOverviewScoreRate,
                        difficulties: .constant(model.difficulties)
                    )
                    .padding(.top)
                }
                .navigationTitle("Analytics.DJLevel.ByDifficulty")
                .automaticNavigationTransition(id: "DJLevel.ByDifficulty", in: analyticsNamespace)
            case .trendsClearTypeGraph:
                VStack {
                    TrendsClearTypeGraph(
                        graphData: $model.clearTypePerImportGroup,
                        difficulty: $levelFilterForTrendsClearType
                    )
                    .chartLegend(.visible)
                    DifficultyPicker(
                        selection: $levelFilterForTrendsClearType,
                        difficulties: .constant(model.difficulties)
                    )
                    .padding(.top)
                }
                .padding()
                .navigationTitle("Analytics.Trends.ClearType")
                .automaticNavigationTransition(id: "Trends.ClearType", in: analyticsNamespace)
            case .trendsDJLevelGraph:
                VStack {
                    TrendsDJLevelGraph(
                        graphData: $model.djLevelPerImportGroup,
                        difficulty: $levelFilterForTrendsDJLevel
                    )
                    .chartLegend(.visible)
                    DifficultyPicker(
                        selection: $levelFilterForTrendsDJLevel,
                        difficulties: .constant(model.difficulties)
                    )
                    .padding(.top)
                }
                .padding()
                .navigationTitle("Analytics.Trends.DJLevel")
                .automaticNavigationTransition(id: "Trends.DJLevel", in: analyticsNamespace)
            case .clearTypeForLevel(let difficulty):
                VStack {
                    TogglableClearTypeDetailView(
                        graphData: $model.clearTypePerDifficulty,
                        difficulty: .constant(difficulty)
                    )
                    .chartLegend(.hidden)
                    ClearTypeLegend()
                        .padding(.horizontal)
                }
                .navigationTitle(perLevelTitle(difficulty, .clearRate))
                .automaticNavigationTransition(
                    id: "ClearType.Level.\(difficulty)", in: analyticsNamespace
                )
            case .clearTypeTrendsForLevel(let difficulty):
                VStack {
                    TrendsClearTypeGraph(
                        graphData: $model.clearTypePerImportGroup,
                        difficulty: .constant(difficulty)
                    )
                    .chartLegend(.hidden)
                    ClearTypeLegend()
                }
                .padding()
                .navigationTitle(perLevelTitle(difficulty, .clearRateTrend))
                .automaticNavigationTransition(
                    id: "ClearTypeTrends.Level.\(difficulty)", in: analyticsNamespace
                )
            case .djLevelForLevel(let difficulty):
                VStack {
                    TogglableDJLevelDetailView(
                        graphData: $model.djLevelPerDifficulty,
                        difficulty: .constant(difficulty)
                    )
                    .chartLegend(.hidden)
                    DJLevelLegend()
                        .padding(.horizontal)
                }
                .navigationTitle(perLevelTitle(difficulty, .djLevel))
                .automaticNavigationTransition(
                    id: "DJLevel.Level.\(difficulty)", in: analyticsNamespace
                )
            case .djLevelTrendsForLevel(let difficulty):
                VStack {
                    TrendsDJLevelGraph(
                        graphData: $model.djLevelPerImportGroup,
                        difficulty: .constant(difficulty)
                    )
                    .chartLegend(.hidden)
                    DJLevelLegend()
                }
                .padding()
                .navigationTitle(perLevelTitle(difficulty, .djLevelTrend))
                .automaticNavigationTransition(
                    id: "DJLevelTrends.Level.\(difficulty)", in: analyticsNamespace
                )
            default:
                newEntryDestination
            }
        }
        .appBackgroundGradient()
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    var newEntryDestination: some View {
        switch path {
        case .newClearsDetail:
            NewClearsDetailView(
                newClears: $model.newClears,
                title: AnalyticsCardType.newClears.titleKey
            )
            .automaticNavigationTransition(id: "NewClears", in: analyticsNamespace)
        case .newAssistClearsDetail:
            NewClearsDetailView(
                newClears: $model.newAssistClears,
                title: AnalyticsCardType.newAssistClears.titleKey
            )
            .automaticNavigationTransition(id: "NewAssistClears", in: analyticsNamespace)
        case .newEasyClearsDetail:
            NewClearsDetailView(
                newClears: $model.newEasyClears,
                title: AnalyticsCardType.newEasyClears.titleKey
            )
            .automaticNavigationTransition(id: "NewEasyClears", in: analyticsNamespace)
        case .newFullComboClearDetail:
            NewClearsDetailView(
                newClears: $model.newFullComboClears,
                title: AnalyticsCardType.newFullComboClear.titleKey
            )
            .automaticNavigationTransition(id: "NewFullComboClear", in: analyticsNamespace)
        case .newHardClearDetail:
            NewClearsDetailView(
                newClears: $model.newHardClears,
                title: AnalyticsCardType.newHardClear.titleKey
            )
            .automaticNavigationTransition(id: "NewHardClear", in: analyticsNamespace)
        case .newExHardClearDetail:
            NewClearsDetailView(
                newClears: $model.newExHardClears,
                title: AnalyticsCardType.newExHardClear.titleKey
            )
            .automaticNavigationTransition(id: "NewExHardClear", in: analyticsNamespace)
        case .newFailedDetail:
            NewClearsDetailView(
                newClears: $model.newFailed,
                title: AnalyticsCardType.newFailed.titleKey
            )
            .automaticNavigationTransition(id: "NewFailed", in: analyticsNamespace)
        case .newHighScoresDetail:
            NewHighScoresDetailView(newHighScores: $model.newHighScores)
                .automaticNavigationTransition(id: "NewHighScores", in: analyticsNamespace)
        case .newAAADetail:
            NewDJLevelsDetailView(
                newDJLevels: $model.newAAA,
                title: AnalyticsCardType.newAAA.titleKey
            )
            .automaticNavigationTransition(id: "NewAAA", in: analyticsNamespace)
        case .newAADetail:
            NewDJLevelsDetailView(
                newDJLevels: $model.newAA,
                title: AnalyticsCardType.newAA.titleKey
            )
            .automaticNavigationTransition(id: "NewAA", in: analyticsNamespace)
        case .newADetail:
            NewDJLevelsDetailView(
                newDJLevels: $model.newA,
                title: AnalyticsCardType.newA.titleKey
            )
            .automaticNavigationTransition(id: "NewA", in: analyticsNamespace)
        default:
            Color.clear
        }
    }
}

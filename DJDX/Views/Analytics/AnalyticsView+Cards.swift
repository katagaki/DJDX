//
//  AnalyticsView+Cards.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Charts
import OrderedCollections
import SwiftUI

// MARK: - Settings Menu & Card Views

extension AnalyticsView {

    var settingsMenu: some View {
        Menu {
            Section("Analytics.Settings.Cards") {
                ForEach(AnalyticsCardType.allCases.filter { !$0.isPinned }) { cardType in
                    Toggle(isOn: Binding<Bool>(
                        get: { visibleCards.contains(cardType) },
                        set: { newValue in
                            withAnimation(.snappy) {
                                if newValue {
                                    visibleCards.insert(cardType)
                                } else {
                                    visibleCards.remove(cardType)
                                }
                                saveVisibleCards()
                            }
                        }
                    )) {
                        Label {
                            cardType.titleText
                        } icon: {
                            Image(systemName: cardType.systemImage)
                        }
                    }
                }
            }
            ForEach(difficulties, id: \.self) { difficulty in
                Section("LEVEL \(difficulty)") {
                    ForEach(AnalyticsPerLevelCategory.allCases) { category in
                        let cardID = PerLevelCardID(difficulty: difficulty, category: category)
                        Toggle(isOn: Binding<Bool>(
                            get: {
                                visiblePerLevelCardSet.contains(cardID)
                            },
                            set: { newValue in
                                withAnimation(.snappy) {
                                    if newValue {
                                        visiblePerLevelCardSet.insert(cardID)
                                    } else {
                                        visiblePerLevelCardSet.remove(cardID)
                                    }
                                    saveVisiblePerLevelCards()
                                }
                            }
                        )) {
                            Text(LocalizedStringKey(category.titleKey))
                        }
                    }
                    Button("Analytics.Settings.HideAll", role: .destructive) {
                        withAnimation(.snappy) {
                            for category in AnalyticsPerLevelCategory.allCases {
                                visiblePerLevelCardSet.remove(
                                    PerLevelCardID(difficulty: difficulty, category: category)
                                )
                            }
                            saveVisiblePerLevelCards()
                        }
                    }
                }
                .menuActionDismissBehavior(.disabled)
            }
            Section {
                Button("Analytics.Settings.ResetAll", role: .destructive) {
                    withAnimation(.snappy) {
                        cardOrder = AnalyticsCardType.defaultOrder
                        visibleCards = AnalyticsCardType.defaultVisible
                        perLevelCardOrder = PerLevelCardID.defaultOrder
                        visiblePerLevelCardSet = PerLevelCardID.defaultVisible
                        saveCardOrder()
                        saveVisibleCards()
                        savePerLevelCardOrder()
                        saveVisiblePerLevelCards()
                    }
                }
            }
        } label: {
            Image(systemName: "pencil")
        }
        .menuActionDismissBehavior(.disabled)
    }

    // MARK: - Card Views

    @ViewBuilder
    func cardView(for cardType: AnalyticsCardType) -> some View {
        switch cardType {
        case .clearTypeOverall:
            EmptyView()
        case .newClears:
            newClearsCard
        case .newAssistClears:
            newAssistClearsCard
        case .newEasyClears:
            newEasyClearsCard
        case .newFullComboClear:
            newFullComboClearCard
        case .newHardClear:
            newHardClearCard
        case .newExHardClear:
            newExHardClearCard
        case .newFailed:
            newFailedCard
        case .newHighScores:
            newHighScoresCard
        }
    }

    var clearTypeOverallCard: some View {
        Button {
            if !isEditingCards && clearTypePerDifficulty.count > 0 {
                navigationManager.push(.clearTypeOverviewGraph, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .clearTypeOverall) {
                OverviewClearTypeOverallGraph(graphData: .constant(filteredClearTypeData))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "ClearType.Overall", in: analyticsNamespace)
    }

    var newClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newClearsDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newClears) {
                NewClearsCard(newClears: $newClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewClears", in: analyticsNamespace)
    }

    var newAssistClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newAssistClearsDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newAssistClears) {
                NewClearsCard(newClears: $newAssistClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewAssistClears", in: analyticsNamespace)
    }

    var newEasyClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newEasyClearsDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newEasyClears) {
                NewClearsCard(newClears: $newEasyClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewEasyClears", in: analyticsNamespace)
    }

    var newFullComboClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newFullComboClearDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newFullComboClear) {
                NewClearsCard(newClears: $newFullComboClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewFullComboClear", in: analyticsNamespace)
    }

    var newHardClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newHardClearDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newHardClear) {
                NewClearsCard(newClears: $newHardClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewHardClear", in: analyticsNamespace)
    }

    var newExHardClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newExHardClearDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newExHardClear) {
                NewClearsCard(newClears: $newExHardClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewExHardClear", in: analyticsNamespace)
    }

    var newFailedCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newFailedDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newFailed) {
                NewClearsCard(newClears: $newFailed)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewFailed", in: analyticsNamespace)
    }

    var newHighScoresCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(.newHighScoresDetail, for: .analytics)
            }
        } label: {
            AnalyticsCardView(cardType: .newHighScores) {
                NewHighScoresCard(newHighScores: $newHighScores)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewHighScores", in: analyticsNamespace)
    }

    // MARK: - Per-Level Card Views

    var visiblePerLevelCards: [PerLevelCardID] {
        perLevelCardOrder.filter { visiblePerLevelCardSet.contains($0) }
    }

    var visibleLevels: Set<Int> {
        Set(visiblePerLevelCardSet.map(\.difficulty))
    }

    @ViewBuilder
    func perLevelCard(difficulty: Int, category: AnalyticsPerLevelCategory) -> some View {
        switch category {
        case .clearRate:
            clearTypeForLevelCard(difficulty: difficulty)
        case .clearRateTrend:
            clearTypeTrendsForLevelCard(difficulty: difficulty)
        case .djLevel:
            djLevelForLevelCard(difficulty: difficulty)
        case .djLevelTrend:
            djLevelTrendsForLevelCard(difficulty: difficulty)
        }
    }

    func clearTypeForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && clearTypePerDifficulty[difficulty] != nil {
                navigationManager.push(.clearTypeForLevel(difficulty: difficulty), for: .analytics)
            }
        } label: {
            AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                              systemImage: "medal.star",
                              iconColor: .secondary) {
                OverviewClearTypePerDifficultyGraph(
                    graphData: $clearTypePerDifficulty,
                    difficulty: .constant(difficulty)
                )
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
            }
            .perLevelCaption("Analytics.PerLevel.Caption.ClearType")
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "ClearType.Level.\(difficulty)", in: analyticsNamespace)
    }

    func clearTypeTrendsForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && clearTypePerImportGroup.count > 0 {
                navigationManager.push(.clearTypeTrendsForLevel(difficulty: difficulty), for: .analytics)
            }
        } label: {
            AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                              systemImage: "medal.star",
                              iconColor: .secondary) {
                TrendsClearTypeGraph(graphData: $clearTypePerImportGroup,
                                     difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
            .perLevelCaption("Analytics.PerLevel.Caption.ClearType")
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(
            id: "ClearTypeTrends.Level.\(difficulty)", in: analyticsNamespace
        )
    }

    func djLevelForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && djLevelPerDifficulty[difficulty] != nil {
                navigationManager.push(.djLevelForLevel(difficulty: difficulty), for: .analytics)
            }
        } label: {
            AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                              systemImage: "medal.star",
                              iconColor: .secondary) {
                OverviewDJLevelPerDifficultyGraph(
                    graphData: $djLevelPerDifficulty,
                    difficulty: .constant(difficulty)
                )
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
            }
            .perLevelCaption("Analytics.PerLevel.Caption.DJLevel")
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "DJLevel.Level.\(difficulty)", in: analyticsNamespace)
    }

    func djLevelTrendsForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && djLevelPerImportGroup.count > 0 {
                navigationManager.push(.djLevelTrendsForLevel(difficulty: difficulty), for: .analytics)
            }
        } label: {
            AnalyticsCardView(verbatimTitle: "LEVEL \(difficulty)",
                              systemImage: "medal.star",
                              iconColor: .secondary) {
                TrendsDJLevelGraph(graphData: $djLevelPerImportGroup,
                                   difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
            .perLevelCaption("Analytics.PerLevel.Caption.DJLevel")
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(
            id: "DJLevelTrends.Level.\(difficulty)", in: analyticsNamespace
        )
    }

    // MARK: - Filtered Data

    var filteredClearTypeData: [Int: OrderedDictionary<String, Int>] {
        clearTypePerDifficulty.filter { visibleLevels.contains($0.key) }
    }

}

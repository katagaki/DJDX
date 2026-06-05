import Charts
import OrderedCollections
import SwiftUI

// MARK: - Card Views

extension AnalyticsView {

    @ViewBuilder
    func cardView(for cardType: AnalyticsCardType) -> some View {
        switch cardType {
        case .clearTypeOverall, .gradeBreakdown, .towerRecent, .towerTotals:
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
        case .newAAA:
            newAAACard
        case .newAA:
            newAACard
        case .newA:
            newACard
        }
    }

    var newClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newClearsDetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newClears, headerPlacement: .bottom) {
                NewClearsCard(newClears: $model.newClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewClears", in: analyticsNamespace)
    }

    var newAssistClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newAssistClearsDetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newAssistClears, headerPlacement: .bottom) {
                NewClearsCard(newClears: $model.newAssistClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewAssistClears", in: analyticsNamespace)
    }

    var newEasyClearsCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newEasyClearsDetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newEasyClears, headerPlacement: .bottom) {
                NewClearsCard(newClears: $model.newEasyClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewEasyClears", in: analyticsNamespace)
    }

    var newFullComboClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newFullComboClearDetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newFullComboClear, headerPlacement: .bottom) {
                NewClearsCard(newClears: $model.newFullComboClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewFullComboClear", in: analyticsNamespace)
    }

    var newHardClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newHardClearDetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newHardClear, headerPlacement: .bottom) {
                NewClearsCard(newClears: $model.newHardClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewHardClear", in: analyticsNamespace)
    }

    var newExHardClearCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newExHardClearDetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newExHardClear, headerPlacement: .bottom) {
                NewClearsCard(newClears: $model.newExHardClears)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewExHardClear", in: analyticsNamespace)
    }

    var newFailedCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newFailedDetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newFailed, headerPlacement: .bottom) {
                NewClearsCard(newClears: $model.newFailed)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewFailed", in: analyticsNamespace)
    }

    var newHighScoresCard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newHighScoresDetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newHighScores, headerPlacement: .bottom) {
                NewHighScoresCard(newHighScores: $model.newHighScores)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewHighScores", in: analyticsNamespace)
    }

    var newAAACard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newAAADetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newAAA, headerPlacement: .bottom) {
                NewDJLevelsCard(newDJLevels: $model.newAAA)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewAAA", in: analyticsNamespace)
    }

    var newAACard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newAADetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newAA, headerPlacement: .bottom) {
                NewDJLevelsCard(newDJLevels: $model.newAA)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewAA", in: analyticsNamespace)
    }

    var newACard: some View {
        Button {
            if !isEditingCards {
                navigationManager.push(AnalyticsPath.newADetail)
            }
        } label: {
            AnalyticsCardView(cardType: .newA, headerPlacement: .bottom) {
                NewDJLevelsCard(newDJLevels: $model.newA)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "NewA", in: analyticsNamespace)
    }

    // MARK: - Per-Level Card Views

    var visiblePerLevelCards: [PerLevelCardID] {
        perLevelCardOrder.filter { visiblePerLevelCardSet.contains($0) }
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

    func clearTypeSegments(difficulty: Int) -> [PerLevelSegment] {
        let counts = model.clearTypePerDifficulty[difficulty] ?? [:]
        return IIDXClearType.sortedStringsWithoutNoPlay.map { clearType in
            PerLevelSegment(
                label: IIDXClearType.abbreviation(for: clearType),
                color: IIDXClearType.color(for: clearType),
                count: counts[clearType] ?? 0
            )
        }
    }

    func djLevelSegments(difficulty: Int) -> [PerLevelSegment] {
        let counts = model.djLevelPerDifficulty[difficulty] ?? [:]
        return IIDXDJLevel.sorted.reversed().map { djLevel in
            PerLevelSegment(
                label: djLevel.rawValue,
                color: IIDXDJLevel.color(for: djLevel.rawValue),
                count: counts[djLevel] ?? 0
            )
        }
    }

    func clearTypeForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && model.clearTypePerDifficulty[difficulty] != nil {
                navigationManager.push(AnalyticsPath.clearTypeForLevel(difficulty: difficulty))
            }
        } label: {
            PerLevelAnalyticsCard(
                difficulty: difficulty,
                subtitle: "Shared.IIDX.ClearType",
                showsBar: true,
                segments: clearTypeSegments(difficulty: difficulty)
            ) {
                TrendsClearTypeGraph(graphData: $model.clearTypePerImportGroup,
                                     difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "ClearType.Level.\(difficulty)", in: analyticsNamespace)
    }

    func clearTypeTrendsForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && model.clearTypePerImportGroup.count > 0 {
                navigationManager.push(AnalyticsPath.clearTypeTrendsForLevel(difficulty: difficulty))
            }
        } label: {
            PerLevelAnalyticsCard(
                difficulty: difficulty,
                subtitle: "Shared.IIDX.ClearType",
                showsBar: false,
                segments: []
            ) {
                TrendsClearTypeGraph(graphData: $model.clearTypePerImportGroup,
                                     difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(
            id: "ClearTypeTrends.Level.\(difficulty)", in: analyticsNamespace
        )
    }

    func djLevelForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && model.djLevelPerDifficulty[difficulty] != nil {
                navigationManager.push(AnalyticsPath.djLevelForLevel(difficulty: difficulty))
            }
        } label: {
            PerLevelAnalyticsCard(
                difficulty: difficulty,
                subtitle: "Shared.IIDX.DJLevel",
                showsBar: true,
                segments: djLevelSegments(difficulty: difficulty)
            ) {
                TrendsDJLevelGraph(graphData: $model.djLevelPerImportGroup,
                                   difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(id: "DJLevel.Level.\(difficulty)", in: analyticsNamespace)
    }

    func djLevelTrendsForLevelCard(difficulty: Int) -> some View {
        Button {
            if !isEditingCards && model.djLevelPerImportGroup.count > 0 {
                navigationManager.push(AnalyticsPath.djLevelTrendsForLevel(difficulty: difficulty))
            }
        } label: {
            PerLevelAnalyticsCard(
                difficulty: difficulty,
                subtitle: "Shared.IIDX.DJLevel",
                showsBar: false,
                segments: []
            ) {
                TrendsDJLevelGraph(graphData: $model.djLevelPerImportGroup,
                                   difficulty: .constant(difficulty))
                    .chartLegend(.hidden)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
            }
        }
        .buttonStyle(AnalyticsCardButtonStyle())
        .automaticMatchedTransitionSource(
            id: "DJLevelTrends.Level.\(difficulty)", in: analyticsNamespace
        )
    }

}

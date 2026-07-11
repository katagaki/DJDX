import Charts
import OrderedCollections
import SwiftUI

struct AnalyticsDestinationView: View {

    @Bindable var model: AnalyticsModel
    let path: AnalyticsPath
    var analyticsNamespace: Namespace.ID

    func perLevelTitle(_ difficulty: Int, _ category: AnalyticsPerLevelCategory) -> String {
        let separator = NSLocalizedString("Analytics.PerLevel.TitleSeparator", comment: "")
        let categoryTitle = NSLocalizedString(category.titleKey, comment: "")
        return "LEVEL \(difficulty)\(separator)\(categoryTitle)"
    }

    var body: some View {
        Group {
            switch path {
            case .clearTypeOverviewGraph:
                ClearTypeOverviewListView(graphData: $model.clearTypePerDifficulty)
                    .navigationTitle("Analytics.ClearType.Overall")
                    .automaticNavigationTransition(id: "ClearType.Overall", in: analyticsNamespace)
            case .gradeBreakdownDetail:
                IIDXGradeBreakdownDetailView(djLevelPerDifficulty: model.djLevelPerDifficulty)
                    .navigationTitle("Analytics.DJLevel.Overall")
                    .automaticNavigationTransition(id: "DJLevel.Overall", in: analyticsNamespace)
            case .clearTypeForLevel(let difficulty):
                ClearTypePerLevelDetailView(model: model, difficulty: difficulty)
                    .navigationTitle(perLevelTitle(difficulty, .clearRate))
                    .automaticNavigationTransition(
                        id: "ClearType.Level.\(difficulty)", in: analyticsNamespace
                    )
            case .clearTypeTrendsForLevel(let difficulty):
                ClearTypePerLevelDetailView(model: model, difficulty: difficulty)
                    .navigationTitle(perLevelTitle(difficulty, .clearRate))
                    .automaticNavigationTransition(
                        id: "ClearTypeTrends.Level.\(difficulty)", in: analyticsNamespace
                    )
            case .djLevelForLevel(let difficulty):
                DJLevelPerLevelDetailView(model: model, difficulty: difficulty)
                    .navigationTitle(perLevelTitle(difficulty, .djLevel))
                    .automaticNavigationTransition(
                        id: "DJLevel.Level.\(difficulty)", in: analyticsNamespace
                    )
            case .djLevelTrendsForLevel(let difficulty):
                DJLevelPerLevelDetailView(model: model, difficulty: difficulty)
                    .navigationTitle(perLevelTitle(difficulty, .djLevel))
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
            NewEntryDetailView(
                entries: model.newClears,
                title: AnalyticsCardType.newClears.titleKey
            )
            .automaticNavigationTransition(id: "NewClears", in: analyticsNamespace)
        case .newAssistClearsDetail:
            NewEntryDetailView(
                entries: model.newAssistClears,
                title: AnalyticsCardType.newAssistClears.titleKey
            )
            .automaticNavigationTransition(id: "NewAssistClears", in: analyticsNamespace)
        case .newEasyClearsDetail:
            NewEntryDetailView(
                entries: model.newEasyClears,
                title: AnalyticsCardType.newEasyClears.titleKey
            )
            .automaticNavigationTransition(id: "NewEasyClears", in: analyticsNamespace)
        case .newFullComboClearDetail:
            NewEntryDetailView(
                entries: model.newFullComboClears,
                title: AnalyticsCardType.newFullComboClear.titleKey
            )
            .automaticNavigationTransition(id: "NewFullComboClear", in: analyticsNamespace)
        case .newHardClearDetail:
            NewEntryDetailView(
                entries: model.newHardClears,
                title: AnalyticsCardType.newHardClear.titleKey
            )
            .automaticNavigationTransition(id: "NewHardClear", in: analyticsNamespace)
        case .newExHardClearDetail:
            NewEntryDetailView(
                entries: model.newExHardClears,
                title: AnalyticsCardType.newExHardClear.titleKey
            )
            .automaticNavigationTransition(id: "NewExHardClear", in: analyticsNamespace)
        case .newFailedDetail:
            NewEntryDetailView(
                entries: model.newFailed,
                title: AnalyticsCardType.newFailed.titleKey
            )
            .automaticNavigationTransition(id: "NewFailed", in: analyticsNamespace)
        case .newHighScoresDetail:
            NewEntryDetailView(
                entries: model.newHighScores,
                title: NSLocalizedString("Analytics.NewHighScores", comment: ""),
                showsClearTypeBreakdown: true,
                scoreDelta: { $0.score.score - $0.previousScore }
            )
            .automaticNavigationTransition(id: "NewHighScores", in: analyticsNamespace)
        case .newAAADetail:
            NewEntryDetailView(
                entries: model.newAAA,
                title: AnalyticsCardType.newAAA.titleKey
            )
            .automaticNavigationTransition(id: "NewAAA", in: analyticsNamespace)
        case .newAADetail:
            NewEntryDetailView(
                entries: model.newAA,
                title: AnalyticsCardType.newAA.titleKey
            )
            .automaticNavigationTransition(id: "NewAA", in: analyticsNamespace)
        case .newADetail:
            NewEntryDetailView(
                entries: model.newA,
                title: AnalyticsCardType.newA.titleKey
            )
            .automaticNavigationTransition(id: "NewA", in: analyticsNamespace)
        default:
            Color.clear
        }
    }
}

struct IIDXGradeBreakdownDetailView: View {
    let djLevelPerDifficulty: [Int: [IIDXDJLevel: Int]]

    var populatedDifficulties: [Int] {
        djLevelPerDifficulty.keys.filter { difficulty in
            (djLevelPerDifficulty[difficulty]?.values.contains(where: { $0 > 0 })) ?? false
        }.sorted()
    }

    var body: some View {
        List {
            if populatedDifficulties.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(populatedDifficulties, id: \.self) { difficulty in
                    Section {
                        Chart(gradeElements(for: difficulty), id: \.key) { element in
                            BarMark(
                                x: .value("Shared.IIDX.DJLevel", element.key),
                                y: .value("Shared.ClearCount", element.value)
                            )
                            .foregroundStyle(IIDXDJLevel.color(for: element.key))
                        }
                        .chartXScale(domain: Array(IIDXDJLevel.sortedStrings.reversed()))
                        .frame(height: 140.0)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(verbatim: "LEVEL \(difficulty)")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    func gradeElements(for difficulty: Int) -> [(key: String, value: Int)] {
        let counts = djLevelPerDifficulty[difficulty] ?? [:]
        return Array(IIDXDJLevel.sortedStrings.reversed()).map { grade in
            (grade, counts[IIDXDJLevel(rawValue: grade) ?? .none] ?? 0)
        }
    }
}

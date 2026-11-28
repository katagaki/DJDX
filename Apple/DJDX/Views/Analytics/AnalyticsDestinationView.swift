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
                    .navigationTransition(.zoom(sourceID: "ClearType.Overall", in: analyticsNamespace))
            case .gradeBreakdownDetail:
                IIDXGradeBreakdownDetailView(djLevelPerDifficulty: model.djLevelPerDifficulty)
                    .navigationTitle("Analytics.DJLevel.Overall")
                    .navigationTransition(.zoom(sourceID: "DJLevel.Overall", in: analyticsNamespace))
            case .progressDetail(let kind):
                IIDXProgressDetailView(points: model.progressPerImportGroup, kind: kind)
                    .navigationTitle(LocalizedStringKey(kind.cardType.titleKey))
                    .navigationTransition(.zoom(sourceID: kind.transitionID, in: analyticsNamespace))
            case .clearTypeForLevel(let difficulty):
                ClearTypePerLevelDetailView(model: model, difficulty: difficulty)
                    .navigationTitle(perLevelTitle(difficulty, .clearRate))
                    .navigationTransition(.zoom(
                        sourceID: "ClearType.Level.\(difficulty)", in: analyticsNamespace
                    ))
            case .clearTypeTrendsForLevel(let difficulty):
                ClearTypePerLevelDetailView(model: model, difficulty: difficulty)
                    .navigationTitle(perLevelTitle(difficulty, .clearRate))
                    .navigationTransition(.zoom(
                        sourceID: "ClearTypeTrends.Level.\(difficulty)", in: analyticsNamespace
                    ))
            case .djLevelForLevel(let difficulty):
                DJLevelPerLevelDetailView(model: model, difficulty: difficulty)
                    .navigationTitle(perLevelTitle(difficulty, .djLevel))
                    .navigationTransition(.zoom(
                        sourceID: "DJLevel.Level.\(difficulty)", in: analyticsNamespace
                    ))
            case .djLevelTrendsForLevel(let difficulty):
                DJLevelPerLevelDetailView(model: model, difficulty: difficulty)
                    .navigationTitle(perLevelTitle(difficulty, .djLevel))
                    .navigationTransition(.zoom(
                        sourceID: "DJLevelTrends.Level.\(difficulty)", in: analyticsNamespace
                    ))
            default:
                newEntryDestination
            }
        }
        .appBackgroundGradient()
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    var newEntryDestination: some View {
        let isSessionsMode = model.sessionStore != nil
        switch path {
        case .newClearsDetail:
            NewEntryDetailView(
                entries: model.newClears,
                title: AnalyticsCardType.newClears.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewClears", in: analyticsNamespace))
        case .newAssistClearsDetail:
            NewEntryDetailView(
                entries: model.newAssistClears,
                title: AnalyticsCardType.newAssistClears.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewAssistClears", in: analyticsNamespace))
        case .newEasyClearsDetail:
            NewEntryDetailView(
                entries: model.newEasyClears,
                title: AnalyticsCardType.newEasyClears.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewEasyClears", in: analyticsNamespace))
        case .newFullComboClearDetail:
            NewEntryDetailView(
                entries: model.newFullComboClears,
                title: AnalyticsCardType.newFullComboClear.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewFullComboClear", in: analyticsNamespace))
        case .newHardClearDetail:
            NewEntryDetailView(
                entries: model.newHardClears,
                title: AnalyticsCardType.newHardClear.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewHardClear", in: analyticsNamespace))
        case .newExHardClearDetail:
            NewEntryDetailView(
                entries: model.newExHardClears,
                title: AnalyticsCardType.newExHardClear.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewExHardClear", in: analyticsNamespace))
        case .newFailedDetail:
            NewEntryDetailView(
                entries: model.newFailed,
                title: AnalyticsCardType.newFailed.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewFailed", in: analyticsNamespace))
        case .newHighScoresDetail:
            NewEntryDetailView(
                entries: model.newHighScores,
                title: NSLocalizedString("Analytics.NewHighScores", comment: ""),
                showsClearTypeBreakdown: true,
                isSessionsMode: isSessionsMode,
                scoreDelta: { $0.score.score - $0.previousScore }
            )
            .navigationTransition(.zoom(sourceID: "NewHighScores", in: analyticsNamespace))
        case .newClearLampsDetail:
            NewEntryDetailView(
                entries: model.newClearLamps,
                title: AnalyticsCardType.newClearLamps.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewClearLamps", in: analyticsNamespace))
        case .newScoreUpdatesDetail:
            NewEntryDetailView(
                entries: model.newScoreUpdates,
                title: AnalyticsCardType.newScoreUpdates.titleKey,
                showsClearTypeBreakdown: true,
                isSessionsMode: isSessionsMode,
                scoreDelta: { $0.score.score - $0.previousScore }
            )
            .navigationTransition(.zoom(sourceID: "NewScoreUpdates", in: analyticsNamespace))
        case .newAAADetail:
            NewEntryDetailView(
                entries: model.newAAA,
                title: AnalyticsCardType.newAAA.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewAAA", in: analyticsNamespace))
        case .newAADetail:
            NewEntryDetailView(
                entries: model.newAA,
                title: AnalyticsCardType.newAA.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewAA", in: analyticsNamespace))
        case .newADetail:
            NewEntryDetailView(
                entries: model.newA,
                title: AnalyticsCardType.newA.titleKey,
                isSessionsMode: isSessionsMode
            )
            .navigationTransition(.zoom(sourceID: "NewA", in: analyticsNamespace))
        default:
            Color.clear
        }
    }
}

struct IIDXGradeBreakdownDetailView: View {
    let djLevelPerDifficulty: [Int: [IIDXDJLevel: Int]]

    @AppStorage(wrappedValue: [], "Analytics.DJLevel.Overall.CardLevels") var cardLevels: Set<String>

    var djLevels: [String] {
        Array(IIDXDJLevel.sortedStrings.reversed())
    }

    var automaticCardLevels: [String] {
        let levelsWithCounts = djLevels.filter { level in
            djLevelPerDifficulty.values.contains { ($0[IIDXDJLevel(rawValue: level) ?? .none] ?? 0) > 0 }
        }
        return Array(levelsWithCounts.prefix(3))
    }

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
                        .chartXAxis {
                            AxisMarks(values: Array(IIDXDJLevel.sortedStrings.reversed())) { value in
                                AxisValueLabel {
                                    if let djLevel = value.as(String.self) {
                                        IIDXMetallicText.djLevel(djLevel)
                                            .font(.caption2)
                                            .fixedSize()
                                    }
                                }
                            }
                        }
                        .chartXScale(domain: Array(IIDXDJLevel.sortedStrings.reversed()))
                        .frame(height: 140.0)
                        .listRowBackground(Color.clear)
                    } header: {
                        LevelNumberBadge(level: String(difficulty))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AnalyticsCardItemsMenu(
                    items: djLevels,
                    automaticItems: automaticCardLevels,
                    selection: $cardLevels
                ) { $0 }
            }
        }
    }

    func gradeElements(for difficulty: Int) -> [(key: String, value: Int)] {
        let counts = djLevelPerDifficulty[difficulty] ?? [:]
        return Array(IIDXDJLevel.sortedStrings.reversed()).map { grade in
            (grade, counts[IIDXDJLevel(rawValue: grade) ?? .none] ?? 0)
        }
    }
}

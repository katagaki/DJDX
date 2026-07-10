import SwiftUI

struct SessionScoreFilterSheet: View {

    @Binding var levelsToShow: Set<IIDXLevel>
    @Binding var difficultiesToShow: Set<IIDXDifficulty>
    @Binding var clearTypesToShow: Set<IIDXClearType>
    @Binding var djLevelsToShow: Set<IIDXDJLevel>

    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(.sharedFilterResetAll, systemImage: "arrow.clockwise") {
                        levelsToShow = []
                        difficultiesToShow = []
                        clearTypesToShow = []
                        djLevelsToShow = []
                    }
                }
                Section(.sharedFilter) {
                    DisclosureGroup {
                        ForEach(IIDXLevel.sorted.filter({ !isBeginnerLevelHidden || $0 != .beginner }),
                                id: \.self) { level in
                            SelectableRow(
                                isSelected: levelsToShow.contains(level)
                            ) {
                                Text(LocalizedStringKey(level.rawValue))
                            } action: {
                                if levelsToShow.contains(level) {
                                    levelsToShow.remove(level)
                                } else {
                                    levelsToShow.insert(level)
                                }
                            }
                        }
                    } label: {
                        FilterDisclosureLabel(.sharedLevel, count: levelsToShow.count,
                                              countLabel: LocalizedStringResource("Shared.Filter.Count.Levels"))
                    }
                    FilterLevelDisclosure {
                        FilterLevelGrid(
                            items: IIDXDifficulty.sorted,
                            selection: difficultiesToShow,
                            title: { String($0.rawValue) },
                            onToggle: { difficulty in
                                if difficultiesToShow.contains(difficulty) {
                                    difficultiesToShow.remove(difficulty)
                                } else {
                                    difficultiesToShow.insert(difficulty)
                                }
                            }
                        )
                    } label: {
                        FilterDisclosureLabel(.sharedDifficulty, count: difficultiesToShow.count,
                                              countLabel: LocalizedStringResource("Shared.Filter.Count.Difficulties"))
                    }
                    DisclosureGroup {
                        ForEach(IIDXClearType.sortedWithoutNoPlay, id: \.self) { clearType in
                            SelectableRow(
                                isSelected: clearTypesToShow.contains(clearType)
                            ) {
                                Text(LocalizedStringKey(clearType.rawValue))
                            } action: {
                                if clearTypesToShow.contains(clearType) {
                                    clearTypesToShow.remove(clearType)
                                } else {
                                    clearTypesToShow.insert(clearType)
                                }
                            }
                        }
                    } label: {
                        FilterDisclosureLabel(
                            LocalizedStringResource("Shared.IIDX.ClearType"),
                            count: clearTypesToShow.count,
                            countLabel: LocalizedStringResource("Shared.Filter.Count.ClearTypes")
                        )
                    }
                    DisclosureGroup {
                        ForEach(IIDXDJLevel.sorted.reversed(), id: \.self) { djLevel in
                            SelectableRow(
                                isSelected: djLevelsToShow.contains(djLevel)
                            ) {
                                Text(verbatim: djLevel.rawValue)
                            } action: {
                                if djLevelsToShow.contains(djLevel) {
                                    djLevelsToShow.remove(djLevel)
                                } else {
                                    djLevelsToShow.insert(djLevel)
                                }
                            }
                        }
                    } label: {
                        FilterDisclosureLabel(
                            LocalizedStringResource("Shared.IIDX.DJLevel"),
                            count: djLevelsToShow.count,
                            countLabel: LocalizedStringResource("Shared.Filter.Count.DJLevels")
                        )
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Shared.Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) {
                            dismiss()
                        }
                    } else {
                        Button(.sharedDone) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

import SwiftUI

struct GITADORAScoreFilterSheet: View {

    @Binding var difficultiesToShow: Set<GITADORADifficulty>
    @Binding var levelsToShow: Set<String>
    @Binding var clearTypesToShow: Set<GITADORAClearType>
    @Binding var ranksToShow: Set<GITADORARank>
    let availableLevels: [String]
    var onReset: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Shared.Filter.ResetAll", systemImage: "arrow.clockwise") {
                        difficultiesToShow = []
                        levelsToShow = []
                        clearTypesToShow = []
                        ranksToShow = []
                        onReset()
                    }
                }
                Section("Shared.Filter") {
                    DisclosureGroup {
                        ForEach(GITADORADifficulty.sorted, id: \.self) { difficulty in
                            GITADORASelectableRow(isSelected: difficultiesToShow.contains(difficulty)) {
                                Text(verbatim: difficulty.rawValue)
                            } action: {
                                toggle(difficulty, in: $difficultiesToShow)
                            }
                        }
                    } label: {
                        GITADORAFilterDisclosureLabel("Shared.Level", count: difficultiesToShow.count)
                    }
                    FilterLevelDisclosure {
                        FilterLevelGrid(
                            items: availableLevels,
                            selection: levelsToShow,
                            title: { $0 },
                            onToggle: { toggle($0, in: $levelsToShow) }
                        )
                    } label: {
                        GITADORAFilterDisclosureLabel("Shared.Sort.Difficulty", count: levelsToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(GITADORAClearType.sorted, id: \.self) { clearType in
                            GITADORASelectableRow(isSelected: clearTypesToShow.contains(clearType)) {
                                Text(verbatim: clearType.rawValue)
                            } action: {
                                toggle(clearType, in: $clearTypesToShow)
                            }
                        }
                    } label: {
                        GITADORAFilterDisclosureLabel("Shared.GITADORA.ClearType",
                                                          count: clearTypesToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(GITADORARank.sorted, id: \.self) { grade in
                            GITADORASelectableRow(isSelected: ranksToShow.contains(grade)) {
                                Text(verbatim: grade.rawValue)
                            } action: {
                                toggle(grade, in: $ranksToShow)
                            }
                        }
                    } label: {
                        GITADORAFilterDisclosureLabel("Shared.GITADORA.Rank",
                                                          count: ranksToShow.count)
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Shared.Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) { dismiss() }
                    } else {
                        Button("Shared.Done") { dismiss() }
                    }
                }
            }
        }
    }

    func toggle<Element: Hashable>(_ element: Element, in binding: Binding<Set<Element>>) {
        if binding.wrappedValue.contains(element) {
            binding.wrappedValue.remove(element)
        } else {
            binding.wrappedValue.insert(element)
        }
    }
}

private struct GITADORAFilterDisclosureLabel: View {
    let title: LocalizedStringKey
    let count: Int

    init(_ title: LocalizedStringKey, count: Int) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if count > 0 {
                Text(verbatim: "\(count)")
                    .foregroundStyle(.secondary)
            } else {
                Text("Shared.All")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GITADORASelectableRow<Label: View>: View {
    var isSelected: Bool
    @ViewBuilder var label: Label
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                label
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct PopnScoreFilterSheet: View {

    @Binding var difficultiesToShow: Set<PopnDifficulty>
    @Binding var levelsToShow: Set<String>
    @Binding var clearTypesToShow: Set<PopnClearType>
    @Binding var ranksToShow: Set<PopnRank>
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
                        ForEach(PopnDifficulty.sorted, id: \.self) { difficulty in
                            PopnSelectableRow(isSelected: difficultiesToShow.contains(difficulty)) {
                                Text(verbatim: difficulty.rawValue)
                            } action: {
                                toggle(difficulty, in: $difficultiesToShow)
                            }
                        }
                    } label: {
                        PopnFilterDisclosureLabel("Shared.Level", count: difficultiesToShow.count)
                    }
                    FilterLevelDisclosure {
                        FilterLevelGrid(
                            items: availableLevels,
                            selection: levelsToShow,
                            title: { $0 },
                            onToggle: { toggle($0, in: $levelsToShow) }
                        )
                    } label: {
                        PopnFilterDisclosureLabel("Shared.Sort.Difficulty", count: levelsToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(PopnClearType.sorted, id: \.self) { clearType in
                            PopnSelectableRow(isSelected: clearTypesToShow.contains(clearType)) {
                                Text(verbatim: clearType.rawValue)
                            } action: {
                                toggle(clearType, in: $clearTypesToShow)
                            }
                        }
                    } label: {
                        PopnFilterDisclosureLabel("Shared.Popn.Medal",
                                                  count: clearTypesToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(PopnRank.sorted, id: \.self) { rank in
                            PopnSelectableRow(isSelected: ranksToShow.contains(rank)) {
                                Text(verbatim: rank.rawValue)
                            } action: {
                                toggle(rank, in: $ranksToShow)
                            }
                        }
                    } label: {
                        PopnFilterDisclosureLabel("Shared.Popn.Rank",
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

private struct PopnFilterDisclosureLabel: View {
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

private struct PopnSelectableRow<Label: View>: View {
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

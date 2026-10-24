import SwiftUI

struct PolarisChordScoreFilterSheet: View {

    @Binding var difficultiesToShow: Set<PolarisChordDifficulty>
    @Binding var levelsToShow: Set<String>
    @Binding var clearTypesToShow: Set<PolarisChordClearType>
    @Binding var gradesToShow: Set<PolarisChordGrade>
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
                        gradesToShow = []
                        onReset()
                    }
                }
                Section("Shared.Filter") {
                    DisclosureGroup {
                        ForEach(PolarisChordDifficulty.sorted, id: \.self) { difficulty in
                            PolarisChordSelectableRow(isSelected: difficultiesToShow.contains(difficulty)) {
                                Text(verbatim: difficulty.rawValue)
                            } action: {
                                toggle(difficulty, in: $difficultiesToShow)
                            }
                        }
                    } label: {
                        PolarisChordFilterDisclosureLabel("Shared.Level", count: difficultiesToShow.count)
                    }
                    FilterLevelDisclosure {
                        FilterLevelGrid(
                            items: availableLevels,
                            selection: levelsToShow,
                            title: { $0 },
                            onToggle: { toggle($0, in: $levelsToShow) }
                        )
                    } label: {
                        PolarisChordFilterDisclosureLabel("Shared.Sort.Difficulty", count: levelsToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(PolarisChordClearType.sorted, id: \.self) { clearType in
                            PolarisChordSelectableRow(isSelected: clearTypesToShow.contains(clearType)) {
                                Text(verbatim: clearType.rawValue)
                            } action: {
                                toggle(clearType, in: $clearTypesToShow)
                            }
                        }
                    } label: {
                        PolarisChordFilterDisclosureLabel("Shared.PolarisChord.ClearType",
                                                          count: clearTypesToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(PolarisChordGrade.sorted, id: \.self) { grade in
                            PolarisChordSelectableRow(isSelected: gradesToShow.contains(grade)) {
                                Text(verbatim: grade.rawValue)
                            } action: {
                                toggle(grade, in: $gradesToShow)
                            }
                        }
                    } label: {
                        PolarisChordFilterDisclosureLabel("Shared.PolarisChord.Grade",
                                                          count: gradesToShow.count)
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

private struct PolarisChordFilterDisclosureLabel: View {
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

private struct PolarisChordSelectableRow<Label: View>: View {
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

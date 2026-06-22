import SwiftUI

struct DDRScoreFilterSheet: View {

    @Binding var isShowingOnlyPlayedCharts: Bool
    @Binding var difficultiesToShow: Set<DDRDifficulty>
    @Binding var levelsToShow: Set<Int>
    @Binding var clearLampsToShow: Set<String>
    @Binding var ranksToShow: Set<String>
    let availableLevels: [Int]
    let availableClearLamps: [String]
    let availableRanks: [String]
    var onReset: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Shared.Filter.ResetAll", systemImage: "arrow.clockwise") {
                        difficultiesToShow = []
                        levelsToShow = []
                        clearLampsToShow = []
                        ranksToShow = []
                        onReset()
                    }
                }
                Section {
                    Toggle(
                        .scoresFilterShowWithScoreOnly, systemImage: "trophy.fill",
                        isOn: $isShowingOnlyPlayedCharts
                    )
                }
                Section("Shared.Filter") {
                    DisclosureGroup {
                        ForEach(DDRDifficulty.sorted, id: \.self) { difficulty in
                            DDRSelectableRow(isSelected: difficultiesToShow.contains(difficulty)) {
                                Text(verbatim: difficulty.rawValue)
                            } action: {
                                toggle(difficulty, in: $difficultiesToShow)
                            }
                        }
                    } label: {
                        DDRFilterDisclosureLabel("Shared.Level", count: difficultiesToShow.count)
                    }
                    FilterLevelDisclosure {
                        FilterLevelGrid(
                            items: availableLevels,
                            selection: levelsToShow,
                            title: { String($0) },
                            onToggle: { toggle($0, in: $levelsToShow) }
                        )
                    } label: {
                        DDRFilterDisclosureLabel("Shared.Sort.Difficulty", count: levelsToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(availableClearLamps, id: \.self) { lamp in
                            DDRSelectableRow(isSelected: clearLampsToShow.contains(lamp)) {
                                Text(verbatim: lamp.uppercased())
                            } action: {
                                toggle(lamp, in: $clearLampsToShow)
                            }
                        }
                    } label: {
                        DDRFilterDisclosureLabel("Shared.DDR.ClearType", count: clearLampsToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(availableRanks, id: \.self) { rank in
                            DDRSelectableRow(isSelected: ranksToShow.contains(rank)) {
                                Text(verbatim: DDRSongRecord.rankDisplay(forStem: rank))
                            } action: {
                                toggle(rank, in: $ranksToShow)
                            }
                        }
                    } label: {
                        DDRFilterDisclosureLabel("Shared.DDR.Rank", count: ranksToShow.count)
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

private struct DDRFilterDisclosureLabel: View {
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

private struct DDRSelectableRow<Label: View>: View {
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

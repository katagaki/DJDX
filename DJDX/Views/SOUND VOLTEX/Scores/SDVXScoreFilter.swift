//
//  SDVXScoreFilter.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI

struct SDVXScoreFilterSheet: View {

    @Binding var difficultiesToShow: Set<SDVXDifficulty>
    @Binding var levelBucketsToShow: Set<Double>
    @Binding var clearTypesToShow: Set<SDVXClearType>
    @Binding var gradesToShow: Set<SDVXGrade>
    let availableLevelBuckets: [Double]
    var onReset: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Shared.Filter.ResetAll", systemImage: "arrow.clockwise") {
                        difficultiesToShow = []
                        levelBucketsToShow = []
                        clearTypesToShow = []
                        gradesToShow = []
                        onReset()
                    }
                }
                Section("Shared.Filter") {
                    DisclosureGroup {
                        ForEach(SDVXDifficulty.sorted.sorted { $0.abbreviation < $1.abbreviation },
                                id: \.self) { difficulty in
                            SDVXSelectableRow(isSelected: difficultiesToShow.contains(difficulty)) {
                                Text(verbatim: difficulty.abbreviation)
                            } action: {
                                toggle(difficulty, in: $difficultiesToShow)
                            }
                        }
                    } label: {
                        SDVXFilterDisclosureLabel("Shared.Level", count: difficultiesToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(availableLevelBuckets, id: \.self) { bucket in
                            SDVXSelectableRow(isSelected: levelBucketsToShow.contains(bucket)) {
                                Text(verbatim: String(format: "%.1f", bucket))
                            } action: {
                                toggle(bucket, in: $levelBucketsToShow)
                            }
                        }
                    } label: {
                        SDVXFilterDisclosureLabel("Shared.Sort.Difficulty", count: levelBucketsToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(SDVXClearType.sorted, id: \.self) { clearType in
                            SDVXSelectableRow(isSelected: clearTypesToShow.contains(clearType)) {
                                Text(verbatim: clearType.rawValue)
                            } action: {
                                toggle(clearType, in: $clearTypesToShow)
                            }
                        }
                    } label: {
                        SDVXFilterDisclosureLabel("Shared.SDVX.ClearType", count: clearTypesToShow.count)
                    }
                    DisclosureGroup {
                        ForEach(SDVXGrade.sorted, id: \.self) { grade in
                            SDVXSelectableRow(isSelected: gradesToShow.contains(grade)) {
                                Text(verbatim: grade.rawValue)
                            } action: {
                                toggle(grade, in: $gradesToShow)
                            }
                        }
                    } label: {
                        SDVXFilterDisclosureLabel("Shared.SDVX.Grade", count: gradesToShow.count)
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

private struct SDVXFilterDisclosureLabel: View {
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

private struct SDVXSelectableRow<Label: View>: View {
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

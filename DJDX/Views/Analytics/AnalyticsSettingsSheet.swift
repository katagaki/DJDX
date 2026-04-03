//
//  AnalyticsSettingsSheet.swift
//  DJDX
//
//  Created on 2026/03/12.
//

import SwiftUI

struct AnalyticsSettingsSheet: View {

    @Binding var visibleCards: Set<AnalyticsCardType>
    @Binding var cardOrder: [AnalyticsCardType]
    @Binding var visiblePerLevelCardSet: Set<PerLevelCardID>
    @Binding var perLevelCardOrder: [PerLevelCardID]
    var onSaveVisibleCards: () -> Void
    var onSaveVisiblePerLevelCards: () -> Void
    var onSaveCardOrder: () -> Void
    var onSavePerLevelCardOrder: () -> Void

    let difficulties: [Int] = Array(1...12)

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
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
                                    onSaveVisibleCards()
                                }
                            }
                        )) {
                            Label {
                                cardType.titleText
                            } icon: {
                                Image(systemName: cardType.systemImage)
                                    .foregroundStyle(cardType.iconColor)
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
                                        onSaveVisiblePerLevelCards()
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
                                onSaveVisiblePerLevelCards()
                            }
                        }
                    }
                }
                Section {
                    Button("Analytics.Settings.ResetAll", role: .destructive) {
                        withAnimation(.snappy) {
                            cardOrder = AnalyticsCardType.defaultOrder
                            visibleCards = AnalyticsCardType.defaultVisible
                            perLevelCardOrder = PerLevelCardID.defaultOrder
                            visiblePerLevelCardSet = PerLevelCardID.defaultVisible
                            onSaveCardOrder()
                            onSaveVisibleCards()
                            onSavePerLevelCardOrder()
                            onSaveVisiblePerLevelCards()
                        }
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Analytics.Settings.Title")
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

//
//  AnalyticsCardType.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import Foundation
import SwiftUI

enum AnalyticsSection: String, Hashable, CaseIterable {
    case overview
    case lastPlay
    case perLevel

    var titleKey: LocalizedStringKey {
        switch self {
        case .overview: "Analytics.Section.Overview"
        case .lastPlay: "Analytics.Section.LastPlay"
        case .perLevel: "Analytics.Section.PerLevel"
        }
    }
}

enum AnalyticsCardType: String, Codable, CaseIterable, Identifiable {
    case clearTypeOverall
    case towerRecent
    case towerTotals
    case newHighScores
    case newAAA
    case newAA
    case newA
    case newFullComboClear
    case newClears
    case newEasyClears
    case newAssistClears
    case newHardClear
    case newExHardClear
    case newFailed

    var id: String { rawValue }

    /// Summary cards are the count-based cards (not clearTypeOverall or tower cards)
    var isSummaryCard: Bool {
        self != .clearTypeOverall && !isTowerCard
    }

    /// Tower cards are IIDX-AC-only full-width chart cards
    var isTowerCard: Bool {
        self == .towerRecent || self == .towerTotals
    }

    var titleText: Text {
        switch self {
        case .clearTypeOverall: return Text("Analytics.ClearType.Overall")
        case .towerRecent: return Text("Tower.ChartMode.Recent")
        case .towerTotals: return Text("Tower.ChartMode.Totals")
        case .newHighScores: return Text("Analytics.NewHighScores")
        case .newFullComboClear: return Text(verbatim: "FULLCOMBO CLEAR")
        case .newClears: return Text(verbatim: "CLEAR")
        case .newEasyClears: return Text(verbatim: "EASY CLEAR")
        case .newAssistClears: return Text(verbatim: "ASSIST CLEAR")
        case .newHardClear: return Text(verbatim: "HARD CLEAR")
        case .newExHardClear: return Text(verbatim: "EX HARD CLEAR")
        case .newFailed: return Text(verbatim: "FAILED")
        case .newAAA: return Text(verbatim: "AAA")
        case .newAA: return Text(verbatim: "AA")
        case .newA: return Text(verbatim: "A")
        }
    }

    var titleKey: String {
        switch self {
        case .clearTypeOverall: return "Analytics.ClearType.Overall"
        case .towerRecent: return "Tower.ChartMode.Recent"
        case .towerTotals: return "Tower.ChartMode.Totals"
        case .newHighScores: return "Analytics.NewHighScores"
        case .newFullComboClear: return "FULLCOMBO CLEAR"
        case .newClears: return "CLEAR"
        case .newEasyClears: return "EASY CLEAR"
        case .newAssistClears: return "ASSIST CLEAR"
        case .newHardClear: return "HARD CLEAR"
        case .newExHardClear: return "EX HARD CLEAR"
        case .newFailed: return "FAILED"
        case .newAAA: return "AAA"
        case .newAA: return "AA"
        case .newA: return "A"
        }
    }

    var systemImage: String {
        switch self {
        case .clearTypeOverall: return "chart.bar"
        case .towerRecent: return "calendar"
        case .towerTotals: return "building.2"
        case .newHighScores: return "trophy"
        case .newFullComboClear: return "star.circle"
        case .newClears: return "checkmark.circle"
        case .newEasyClears: return "checkmark.shield"
        case .newAssistClears: return "bolt.shield"
        case .newHardClear: return "dial.medium"
        case .newExHardClear: return "dial.high"
        case .newFailed: return "exclamationmark.octagon"
        case .newAAA: return "crown"
        case .newAA: return "crown"
        case .newA: return "crown"
        }
    }

    var iconColor: Color {
        switch self {
        case .clearTypeOverall: return .blue
        case .towerRecent: return .red
        case .towerTotals: return .red
        case .newHighScores: return .orange
        case .newFullComboClear: return .blue
        case .newClears: return .cyan
        case .newEasyClears: return .green
        case .newAssistClears: return .purple
        case .newHardClear: return .pink
        case .newExHardClear: return .yellow
        case .newFailed: return .red
        case .newAAA: return .orange
        case .newAA: return .orange
        case .newA: return .orange
        }
    }

    /// Fixed content height for the card body (excluding header)
    var cardContentHeight: CGFloat {
        switch self {
        case .clearTypeOverall: return 80.0
        case .towerRecent, .towerTotals: return 80.0
        case .newFullComboClear,
             .newClears,
             .newEasyClears,
             .newAssistClears,
             .newHardClear,
             .newExHardClear,
             .newFailed,
             .newHighScores,
             .newAAA,
             .newAA,
             .newA:
            return 50.0
        }
    }

    /// Whether this card is pinned (cannot be reordered past)
    var isPinned: Bool {
        self == .clearTypeOverall
    }

    /// Tower cards, shown in their own section
    static var towerCards: [AnalyticsCardType] {
        [.towerTotals, .towerRecent]
    }

    /// Default card order
    static var defaultOrder: [AnalyticsCardType] {
        [
            .clearTypeOverall,
            .towerTotals,
            .towerRecent,
            .newHighScores,
            .newAAA,
            .newAA,
            .newA,
            .newFullComboClear,
            .newClears,
            .newEasyClears,
            .newAssistClears,
            .newHardClear,
            .newExHardClear,
            .newFailed
        ]
    }

    /// Default visible cards
    static var defaultVisible: Set<AnalyticsCardType> {
        [.clearTypeOverall, .towerTotals, .newHighScores, .newClears, .newAssistClears]
    }
}

//
//  AnalyticsCardType.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import Foundation
import SwiftUI

enum AnalyticsCardType: String, Codable, CaseIterable, Identifiable {
    case clearTypeOverall
    case newClears
    case newAssistClears
    case newEasyClears
    case newFullComboClear
    case newHardClear
    case newExHardClear
    case newFailed
    case newHighScores

    var id: String { rawValue }

    /// Summary cards are the count-based cards (not clearTypeOverall)
    var isSummaryCard: Bool {
        self != .clearTypeOverall
    }

    var titleText: Text {
        switch self {
        case .clearTypeOverall: return Text("Analytics.ClearType.Overall")
        case .newClears: return Text(verbatim: "NEW CLEAR")
        case .newAssistClears: return Text(verbatim: "NEW ASSIST CLEAR")
        case .newEasyClears: return Text(verbatim: "NEW EASY CLEAR")
        case .newFullComboClear: return Text(verbatim: "NEW FULL COMBO CLEAR")
        case .newHardClear: return Text(verbatim: "NEW HARD CLEAR")
        case .newExHardClear: return Text(verbatim: "NEW EX HARD CLEAR")
        case .newFailed: return Text(verbatim: "NEW FAILED")
        case .newHighScores: return Text("Analytics.NewHighScores")
        }
    }

    var titleKey: String {
        switch self {
        case .clearTypeOverall: return "Analytics.ClearType.Overall"
        case .newClears: return "NEW CLEAR"
        case .newAssistClears: return "NEW ASSIST CLEAR"
        case .newEasyClears: return "NEW EASY CLEAR"
        case .newFullComboClear: return "NEW FULL COMBO CLEAR"
        case .newHardClear: return "NEW HARD CLEAR"
        case .newExHardClear: return "NEW EX HARD CLEAR"
        case .newFailed: return "NEW FAILED"
        case .newHighScores: return "Analytics.NewHighScores"
        }
    }

    var systemImage: String {
        switch self {
        case .clearTypeOverall: return "chart.bar.fill"
        case .newClears: return "checkmark.circle.fill"
        case .newAssistClears: return "heart.gauge.open"
        case .newEasyClears: return "leaf.fill"
        case .newFullComboClear: return "star.circle.fill"
        case .newHardClear: return "bolt.circle.fill"
        case .newExHardClear: return "bolt.trianglebadge.exclamationmark"
        case .newFailed: return "xmark.circle.fill"
        case .newHighScores: return "trophy.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .clearTypeOverall: return .blue
        case .newClears: return .cyan
        case .newAssistClears: return .purple
        case .newEasyClears: return .green
        case .newFullComboClear: return .blue
        case .newHardClear: return .pink
        case .newExHardClear: return .yellow
        case .newFailed: return .red
        case .newHighScores: return .orange
        }
    }

    /// Fixed content height for the card body (excluding header)
    var cardContentHeight: CGFloat {
        switch self {
        case .clearTypeOverall: return 80.0
        case .newClears,
             .newAssistClears,
             .newEasyClears,
             .newFullComboClear,
             .newHardClear,
             .newExHardClear,
             .newFailed,
             .newHighScores:
            return 60.0
        }
    }

    /// Whether this card is pinned (cannot be reordered past)
    var isPinned: Bool {
        self == .clearTypeOverall
    }

    /// Whether this card always spans the full width
    var isFullWidth: Bool {
        self == .clearTypeOverall
    }

    /// Default card order
    static var defaultOrder: [AnalyticsCardType] {
        [
            .clearTypeOverall,
            .newClears,
            .newAssistClears,
            .newEasyClears,
            .newFullComboClear,
            .newHardClear,
            .newExHardClear,
            .newFailed,
            .newHighScores
        ]
    }

    /// Default visible cards
    static var defaultVisible: Set<AnalyticsCardType> {
        [.clearTypeOverall, .newClears, .newAssistClears]
    }

    /// Cards that show side by side by default
    static var pairedCards: [(AnalyticsCardType, AnalyticsCardType)] {
        [
            (.newClears, .newAssistClears)
        ]
    }
}

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

    /// Summary cards are the count-based cards (not clearTypeOverall)
    var isSummaryCard: Bool {
        self != .clearTypeOverall
    }

    var titleText: Text {
        switch self {
        case .clearTypeOverall: return Text("Analytics.ClearType.Overall")
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

    /// Default card order
    static var defaultOrder: [AnalyticsCardType] {
        [
            .clearTypeOverall,
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
        [.clearTypeOverall, .newHighScores, .newClears, .newAssistClears]
    }
}

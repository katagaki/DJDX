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
    case newFailed
    case newHighScores

    var id: String { rawValue }

    var titleText: Text {
        switch self {
        case .clearTypeOverall: return Text("Analytics.ClearType.Overall")
        case .newClears: return Text(verbatim: "NEW CLEAR")
        case .newAssistClears: return Text(verbatim: "NEW ASSIST CLEAR")
        case .newEasyClears: return Text(verbatim: "NEW EASY CLEAR")
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
        case .newFailed: return "NEW FAILED"
        case .newHighScores: return "Analytics.NewHighScores"
        }
    }

    var systemImage: String {
        switch self {
        case .clearTypeOverall: return "chart.bar.fill"
        case .newClears: return "checkmark.circle.fill"
        case .newAssistClears: return "hand.raised.fill"
        case .newEasyClears: return "leaf.fill"
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
        case .newFailed: return .red
        case .newHighScores: return .orange
        }
    }

    /// Fixed content height for the card body (excluding header)
    var cardContentHeight: CGFloat {
        return 100.0
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
            .newFailed,
            .newHighScores
        ]
    }

    /// Cards that show side by side by default
    static var pairedCards: [(AnalyticsCardType, AnalyticsCardType)] {
        [
            (.newClears, .newAssistClears)
        ]
    }
}

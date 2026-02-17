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
    case newHighScores
    case djLevelByDifficulty
    case djLevelTrends

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .clearTypeOverall: return "Analytics.ClearType.Overall"
        case .newClears: return "Analytics.NewClears"
        case .newHighScores: return "Analytics.NewHighScores"
        case .djLevelByDifficulty: return "Analytics.DJLevel.ByDifficulty"
        case .djLevelTrends: return "Analytics.Trends.DJLevel"
        }
    }

    var systemImage: String {
        switch self {
        case .clearTypeOverall: return "chart.bar.fill"
        case .newClears: return "sparkles"
        case .newHighScores: return "trophy.fill"
        case .djLevelByDifficulty: return "chart.bar.fill"
        case .djLevelTrends: return "chart.xyaxis.line"
        }
    }

    var iconColor: Color {
        switch self {
        case .clearTypeOverall: return .blue
        case .newClears: return .green
        case .newHighScores: return .orange
        case .djLevelByDifficulty: return .pink
        case .djLevelTrends: return .teal
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
            .newHighScores,
            .djLevelByDifficulty,
            .djLevelTrends
        ]
    }

    /// Cards that show side by side by default
    static var pairedCards: [(AnalyticsCardType, AnalyticsCardType)] {
        [
            (.newClears, .newHighScores),
            (.djLevelByDifficulty, .djLevelTrends)
        ]
    }
}

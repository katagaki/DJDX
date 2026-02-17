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
    case clearTypeByDifficulty
    case clearTypeTrends
    case djLevelByDifficulty
    case djLevelTrends

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .clearTypeOverall: return "Analytics.ClearType.Overall"
        case .newClears: return "Analytics.NewClears"
        case .newHighScores: return "Analytics.NewHighScores"
        case .clearTypeByDifficulty: return "Analytics.ClearType.ByDifficulty"
        case .clearTypeTrends: return "Analytics.Trends.ClearType"
        case .djLevelByDifficulty: return "Analytics.DJLevel.ByDifficulty"
        case .djLevelTrends: return "Analytics.Trends.DJLevel"
        }
    }

    var systemImage: String {
        switch self {
        case .clearTypeOverall: return "chart.bar.fill"
        case .newClears: return "sparkles"
        case .newHighScores: return "trophy.fill"
        case .clearTypeByDifficulty: return "chart.pie.fill"
        case .clearTypeTrends: return "chart.xyaxis.line"
        case .djLevelByDifficulty: return "chart.bar.fill"
        case .djLevelTrends: return "chart.xyaxis.line"
        }
    }

    var iconColor: Color {
        switch self {
        case .clearTypeOverall: return .blue
        case .newClears: return .green
        case .newHighScores: return .orange
        case .clearTypeByDifficulty: return .purple
        case .clearTypeTrends: return .cyan
        case .djLevelByDifficulty: return .pink
        case .djLevelTrends: return .teal
        }
    }

    /// Fixed content height for the card body (excluding header)
    var cardContentHeight: CGFloat {
        switch self {
        case .clearTypeOverall: return 160.0
        case .newClears, .newHighScores: return 60.0
        case .clearTypeByDifficulty, .clearTypeTrends,
             .djLevelByDifficulty, .djLevelTrends: return 100.0
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
            .newHighScores,
            .clearTypeByDifficulty,
            .clearTypeTrends,
            .djLevelByDifficulty,
            .djLevelTrends
        ]
    }

    /// Cards that show side by side by default
    static var pairedCards: [(AnalyticsCardType, AnalyticsCardType)] {
        [
            (.newClears, .newHighScores),
            (.clearTypeByDifficulty, .clearTypeTrends),
            (.djLevelByDifficulty, .djLevelTrends)
        ]
    }
}

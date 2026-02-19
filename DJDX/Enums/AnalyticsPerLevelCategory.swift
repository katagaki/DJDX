//
//  AnalyticsPerLevelCategory.swift
//  DJDX
//
//  Created on 2026/02/19.
//

import Foundation
import SwiftUI

enum AnalyticsPerLevelCategory: String, Codable, CaseIterable, Identifiable {
    case clearRate
    case clearRateTrend
    case djLevel
    case djLevelTrend

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .clearRate: return "Analytics.PerLevel.ClearRate"
        case .clearRateTrend: return "Analytics.PerLevel.ClearRateTrend"
        case .djLevel: return "Analytics.PerLevel.DJLevel"
        case .djLevelTrend: return "Analytics.PerLevel.DJLevelTrend"
        }
    }

    var systemImage: String {
        switch self {
        case .clearRate: return "chart.pie.fill"
        case .clearRateTrend: return "chart.xyaxis.line"
        case .djLevel: return "chart.bar.fill"
        case .djLevelTrend: return "chart.xyaxis.line"
        }
    }

    var iconColor: Color {
        switch self {
        case .clearRate: return .purple
        case .clearRateTrend: return .cyan
        case .djLevel: return .pink
        case .djLevelTrend: return .teal
        }
    }

    static var defaultVisible: Set<AnalyticsPerLevelCategory> {
        [.clearRate, .clearRateTrend]
    }
}

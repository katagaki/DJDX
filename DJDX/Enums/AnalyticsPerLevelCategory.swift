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
        case .clearRate: return "Shared.IIDX.ClearType"
        case .clearRateTrend: return "Analytics.PerLevel.ClearTypeTrend"
        case .djLevel: return "Shared.IIDX.DJLevel"
        case .djLevelTrend: return "Analytics.PerLevel.DJLevelTrend"
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

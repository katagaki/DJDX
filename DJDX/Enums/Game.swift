//
//  Game.swift
//  DJDX
//
//  Created by Claude on 2026/05/29.
//

import SwiftUI

enum Game: Int, Codable, CaseIterable, Identifiable {
    case iidxArcade = 0
    case soundVoltex = 1
    case iidxInfinitas = 2

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .iidxArcade: "beatmania IIDX"
        case .soundVoltex: "SOUND VOLTEX"
        case .iidxInfinitas: "beatmania IIDX INFINITAS"
        }
    }

    var iconResource: ImageResource? {
        switch self {
        case .iidxArcade, .iidxInfinitas: .iconIIDX
        case .soundVoltex: .iconSDVX
        }
    }

    // Only IIDX AC ships in Phase 0; the other games become selectable as their phases land.
    var isAvailable: Bool {
        switch self {
        case .iidxArcade, .soundVoltex: true
        case .iidxInfinitas: false
        }
    }

    // IIDX AC and INFINITAS share the same data structure (SP/DP, 5 difficulties, EX score).
    var isIIDXFamily: Bool {
        switch self {
        case .iidxArcade, .iidxInfinitas: true
        case .soundVoltex: false
        }
    }

    var supportsPlayType: Bool { isIIDXFamily }

    var supportsTower: Bool {
        switch self {
        case .iidxArcade: true
        case .soundVoltex, .iidxInfinitas: false
        }
    }

    // The qpro + notes radar profile section is IIDX-AC-only for now.
    var supportsProfile: Bool {
        switch self {
        case .iidxArcade: true
        case .soundVoltex, .iidxInfinitas: false
        }
    }

    var databaseFileName: String {
        switch self {
        case .iidxArcade: "PlayData.db"
        case .soundVoltex: "PlayDataSDVX.db"
        case .iidxInfinitas: "PlayDataInfinitas.db"
        }
    }
}

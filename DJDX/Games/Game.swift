import SwiftUI

enum Game: Int, Codable, CaseIterable, Identifiable {
    case iidxArcade = 0
    case soundVoltex = 1
    case iidxInfinitas = 2
    case polarisChord = 3
    case danceDanceRevolution = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .iidxArcade: "beatmania IIDX"
        case .soundVoltex: "SOUND VOLTEX"
        case .iidxInfinitas: "beatmania IIDX INFINITAS"
        case .polarisChord: "ポラリスコード"
        case .danceDanceRevolution: "DanceDanceRevolution"
        }
    }

    var shortName: String {
        switch self {
        case .iidxArcade: "IIDX"
        case .soundVoltex: "SDVX"
        case .iidxInfinitas: "INFINITAS"
        case .polarisChord: "ぽらりこ"
        case .danceDanceRevolution: "DDR"
        }
    }

    var iconResource: ImageResource? {
        switch self {
        case .iidxArcade, .iidxInfinitas: .iconIIDX
        case .soundVoltex: .iconSDVX
        case .polarisChord: .iconPolarisChord
        case .danceDanceRevolution: .iconDDR
        }
    }

    var accentColor: Color {
        switch self {
        case .iidxArcade, .iidxInfinitas: .accent
        case .soundVoltex: Color(red: 0.93, green: 0.27, blue: 0.64)
        case .polarisChord: Color(red: 0.26, green: 0.62, blue: 0.96)
        case .danceDanceRevolution: Color(red: 0.98, green: 0.55, blue: 0.13)
        }
    }

    var backgroundGradientColors: [Color] {
        [accentColor.opacity(0.18), accentColor.opacity(0.06), .clear]
    }

    // Only IIDX AC ships in Phase 0; the other games become selectable as their phases land.
    var isAvailable: Bool {
        switch self {
        case .iidxArcade, .soundVoltex, .polarisChord, .danceDanceRevolution: true
        case .iidxInfinitas: false
        }
    }

    // IIDX AC and INFINITAS share the same data structure (SP/DP, 5 difficulties, EX score).
    var isIIDXFamily: Bool {
        switch self {
        case .iidxArcade, .iidxInfinitas: true
        case .soundVoltex, .polarisChord, .danceDanceRevolution: false
        }
    }

    var supportsPlayType: Bool { isIIDXFamily }

    var supportsSessions: Bool {
        self == .iidxArcade
    }

    var supportsTower: Bool {
        switch self {
        case .iidxArcade: true
        case .soundVoltex, .iidxInfinitas, .polarisChord, .danceDanceRevolution: false
        }
    }

    // The qpro + notes radar profile section is IIDX-AC-only for now.
    var supportsProfile: Bool {
        self == .iidxArcade
    }

    var databaseFileName: String {
        switch self {
        case .iidxArcade: "PlayData.db"
        case .soundVoltex: "PlayDataSDVX.db"
        case .iidxInfinitas: "PlayDataInfinitas.db"
        case .polarisChord: "PlayDataPolarisChord.db"
        case .danceDanceRevolution: "PlayDataDDR.db"
        }
    }
}

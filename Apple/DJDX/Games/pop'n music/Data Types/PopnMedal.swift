import SwiftUI

enum PopnMedal: String, Codable, CaseIterable {
    case perfect = "a"
    case fullComboStar = "b"
    case fullComboDiamond = "c"
    case fullComboCircle = "d"
    case clearStar = "e"
    case clearDiamond = "f"
    case clearCircle = "g"
    case failedStar = "h"
    case failedDiamond = "i"
    case failedCircle = "j"
    case easyClear = "k"
    case assistClear = "l"
    case noPlay = "none"

    static let sorted: [PopnMedal] = [
        .perfect, .fullComboStar, .fullComboDiamond, .fullComboCircle,
        .clearStar, .clearDiamond, .clearCircle, .easyClear, .assistClear,
        .failedStar, .failedDiamond, .failedCircle, .noPlay
    ]

    init(code: String) {
        self = PopnMedal(rawValue: code.lowercased()) ?? .noPlay
    }

    var clearType: PopnClearType {
        switch self {
        case .perfect: .perfect
        case .fullComboStar, .fullComboDiamond, .fullComboCircle: .fullCombo
        case .clearStar, .clearDiamond, .clearCircle: .clear
        case .easyClear: .easyClear
        case .assistClear: .assistClear
        case .failedStar, .failedDiamond, .failedCircle: .failed
        case .noPlay: .noPlay
        }
    }

    var shape: String {
        switch self {
        case .fullComboStar, .clearStar, .failedStar: "★"
        case .fullComboDiamond, .clearDiamond, .failedDiamond: "◆"
        case .fullComboCircle, .clearCircle, .failedCircle: "●"
        default: ""
        }
    }

    var abbreviation: String {
        clearType.abbreviation + shape
    }

    var popnClassBonus: Int {
        switch clearType {
        case .perfect, .fullCombo: 5000
        case .clear, .easyClear: 3000
        default: 0
        }
    }
}

enum PopnClearType: String, Codable, CaseIterable {
    case perfect = "PERFECT"
    case fullCombo = "FULL COMBO"
    case clear = "CLEAR"
    case easyClear = "EASY CLEAR"
    case assistClear = "ASSIST CLEAR"
    case failed = "FAILED"
    case noPlay = "NO PLAY"

    static let sorted: [PopnClearType] = [
        .perfect, .fullCombo, .clear, .easyClear, .assistClear, .failed, .noPlay
    ]

    static let sortedWithoutNoPlay: [PopnClearType] = [
        .perfect, .fullCombo, .clear, .easyClear, .assistClear, .failed
    ]

    static var sortedStringsWithoutNoPlay: [String] {
        sortedWithoutNoPlay.map { $0.rawValue }
    }

    var abbreviation: String {
        switch self {
        case .perfect: "PFT"
        case .fullCombo: "FC"
        case .clear: "CLR"
        case .easyClear: "EC"
        case .assistClear: "AC"
        case .failed: "FAIL"
        case .noPlay: "NP"
        }
    }

    var color: Color {
        switch self {
        case .perfect: .yellow
        case .fullCombo: .cyan
        case .clear: .orange
        case .easyClear: .green
        case .assistClear: .purple
        case .failed: .red
        case .noPlay: .gray
        }
    }
}

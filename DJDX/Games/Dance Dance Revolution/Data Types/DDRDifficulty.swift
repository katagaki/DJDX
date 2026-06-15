import SwiftUI

enum DDRDifficulty: String, Codable, CaseIterable {
    case beginner = "BEGINNER"
    case basic = "BASIC"
    case difficult = "DIFFICULT"
    case expert = "EXPERT"
    case challenge = "CHALLENGE"
    case unknown = ""

    init(index: Int) {
        switch index {
        case 0: self = .beginner
        case 1: self = .basic
        case 2: self = .difficult
        case 3: self = .expert
        case 4: self = .challenge
        default: self = .unknown
        }
    }

    static let sorted: [DDRDifficulty] = [.beginner, .basic, .difficult, .expert, .challenge]

    var abbreviation: String {
        switch self {
        case .beginner: "BEG"
        case .basic: "BAS"
        case .difficult: "DIF"
        case .expert: "EXP"
        case .challenge: "CHA"
        case .unknown: ""
        }
    }

    var color: Color {
        switch self {
        case .beginner: Color(red: 0.0, green: 0.7, blue: 1.0)
        case .basic: Color(red: 0.95, green: 0.7, blue: 0.0)
        case .difficult: .red
        case .expert: .green
        case .challenge: Color(red: 0.65, green: 0.2, blue: 0.9)
        case .unknown: .gray
        }
    }
}

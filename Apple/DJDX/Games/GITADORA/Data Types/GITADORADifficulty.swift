import SwiftUI

enum GITADORADifficulty: String, Codable, CaseIterable {
    case all = "Shared.All"
    case basic = "BASIC"
    case advanced = "ADVANCED"
    case extreme = "EXTREME"
    // swiftlint:disable:next inclusive_language
    case master = "MASTER"
    case unknown = ""

    static let sorted: [GITADORADifficulty] = [.basic, .advanced, .extreme, .master]

    var abbreviation: String {
        switch self {
        case .all: "ALL"
        case .basic: "BSC"
        case .advanced: "ADV"
        case .extreme: "EXT"
        case .master: "MAS"
        case .unknown: ""
        }
    }

    var color: Color {
        switch self {
        case .basic: .blue
        case .advanced: Color(red: 0.95, green: 0.65, blue: 0.0)
        case .extreme: .red
        case .master: .purple
        default: .gray
        }
    }
}

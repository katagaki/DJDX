import Foundation

enum GITADORAInstrument: String, Codable, CaseIterable {
    case guitar = "GUITAR"
    case bass = "BASS"
    case drum = "DRUM"

    var gameType: String {
        switch self {
        case .guitar, .bass: "gf"
        case .drum: "dm"
        }
    }

    var abbreviation: String {
        switch self {
        case .guitar: "G"
        case .bass: "B"
        case .drum: "D"
        }
    }

    var displayName: String {
        switch self {
        case .guitar: "GUITAR"
        case .bass: "BASS"
        case .drum: "DRUM"
        }
    }
}

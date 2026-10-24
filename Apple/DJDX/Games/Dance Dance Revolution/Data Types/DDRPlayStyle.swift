import Foundation

enum DDRPlayStyle: String, Codable, CaseIterable {
    case single = "SINGLE"
    case double = "DOUBLE"

    var styleParameter: Int {
        switch self {
        case .single: 0
        case .double: 1
        }
    }

    var pageName: String {
        switch self {
        case .single: "music_data_single.html"
        case .double: "music_data_double.html"
        }
    }

    var abbreviation: String {
        switch self {
        case .single: "SP"
        case .double: "DP"
        }
    }
}

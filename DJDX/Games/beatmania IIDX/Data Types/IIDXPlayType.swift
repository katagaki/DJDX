import Foundation

enum IIDXPlayType: String, Codable {
    case single
    case double

    func displayName() -> String {
        switch self {
        case .single: "SP"
        case .double: "DP"
        }
    }
}

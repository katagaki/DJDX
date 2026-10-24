import Foundation

enum IIDXImportMode: String, Codable {
    case single
    case double
    case tower

    var playType: IIDXPlayType? {
        switch self {
        case .single: return .single
        case .double: return .double
        default: return nil
        }
    }
}

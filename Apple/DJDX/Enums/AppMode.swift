import Foundation

enum AppMode: Int, Codable, CaseIterable, Identifiable {
    case imports = 0
    case sessions = 1

    var id: Int { rawValue }
}

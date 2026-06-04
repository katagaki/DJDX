import Foundation

struct SDVXInChart: Sendable, Hashable {
    var code: String
    var slot: String
    var title: String
    var level: Int

    var folder: String { String(code.prefix(2)) }

    var pageURL: URL? {
        URL(string: "https://sdvx.in/\(folder)/\(code)\(slot).htm")
    }
}

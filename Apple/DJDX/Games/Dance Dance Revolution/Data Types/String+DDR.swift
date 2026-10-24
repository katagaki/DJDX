import Foundation

extension String {
    var ddrCompact: String {
        var normalized = replacingOccurrences(of: "【[^】]*】", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(
            of: "\\*[0-9]+\\s*$", with: "", options: .regularExpression
        )
        return normalized.compact
    }
}

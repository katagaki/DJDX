import Foundation

extension String {
    // Normalizes a DDR title for joining e-amusement play data against BEMANIWiki:
    // drops the 【…】 circle/artist suffix e-amusement appends (e.g.
    // "チルノのパーフェクトさんすう学園【ビートまりお】") and BEMANIWiki's trailing
    // "*N" footnote markers, then compacts.
    var ddrCompact: String {
        var normalized = replacingOccurrences(of: "【[^】]*】", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(
            of: "\\*[0-9]+\\s*$", with: "", options: .regularExpression
        )
        return normalized.compact
    }
}

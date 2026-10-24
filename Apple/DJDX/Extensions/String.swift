import Foundation

let charactersToReplace = [
    "Ø": "O",
    "！": "!",
    "？": "?",
    "（": "(",
    "）": ")",
    "〜": "~",
    "ー": "-",
    "，": ",",
    "　": "",
    " ": "",
    "・": "•",
    "“": "\"",
    "”": "\"",
    "‘": "'",
    "’": "'",
    "／": "/",
    "¡": "!",
    "：": ":",
    "■": "",
    "□": "",
    "★": "",
    "☆": "",
    "♥": "",
    "♡": "",
    "Ʞ": "K",
    "И": "N"
]

private let characterReplacements: [Character: String] = charactersToReplace.reduce(into: [:]) {
    if let character = $1.key.first, $1.key.count == 1 {
        $0[character] = $1.value
    }
}

extension String {
    var compact: String {
        var filteredString = ""
        filteredString.reserveCapacity(count)
        for character in precomposedStringWithCompatibilityMapping {
            if let replacement = characterReplacements[character] {
                filteredString.append(replacement)
            } else {
                filteredString.append(character)
            }
        }
        return filteredString.folding(options: .diacriticInsensitive, locale: nil).lowercased()
    }

    func editRatio(to other: String) -> Double {
        let lhs = Array(self)
        let rhs = Array(other)
        let longest = max(lhs.count, rhs.count)
        guard longest > 0 else { return 0.0 }
        return Double(Self.levenshtein(lhs, rhs)) / Double(longest)
    }

    private static func levenshtein(_ lhs: [Character], _ rhs: [Character]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }
        var previous = Array(0...rhs.count)
        var current = [Int](repeating: 0, count: rhs.count + 1)
        for row in 1...lhs.count {
            current[0] = row
            for col in 1...rhs.count {
                let cost = lhs[row - 1] == rhs[col - 1] ? 0 : 1
                current[col] = Swift.min(previous[col] + 1, current[col - 1] + 1, previous[col - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[rhs.count]
    }
}

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

extension String {
    var compact: String {
        var filteredString = precomposedStringWithCompatibilityMapping
        for (characterToReplace, characterToReplaceWith) in charactersToReplace {
            filteredString = filteredString.replacingOccurrences(of: characterToReplace, with: characterToReplaceWith)
        }
        filteredString = filteredString.folding(options: .diacriticInsensitive, locale: nil)
        return filteredString.lowercased()
    }
}

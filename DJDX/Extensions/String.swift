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
        var filteredString = self
        for (characterToReplace, characterToReplaceWith) in charactersToReplace {
            filteredString = filteredString.replacingOccurrences(of: characterToReplace, with: characterToReplaceWith)
        }
        return filteredString.lowercased()
    }
}

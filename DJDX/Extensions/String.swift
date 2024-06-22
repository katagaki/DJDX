//
//  String.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/05.
//

import Foundation

extension String {
    var compact: String {
        let charactersToFilter = CharacterSet(",，“”\"'‘’ 　！!¡？?:(（)）~〜-ー■□☆★♡♥".unicodeScalars)
        let charactersToReplace = [ "Ø" : "O" ]
        var filteredString = String(self.unicodeScalars.filter(charactersToFilter.inverted.contains))
            .lowercased()
        for (characterToReplace, characterToReplaceWith) in charactersToReplace {
            filteredString = filteredString.replacingOccurrences(of: characterToReplace, with: characterToReplaceWith)
        }
        return filteredString
    }
}

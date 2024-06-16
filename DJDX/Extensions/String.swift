//
//  String.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/05.
//

import Foundation

extension String {
    var compact: String {
        let charactersToFilter = CharacterSet("“”\"'‘’ 　！!¡？?:(（)）~〜-ー■□☆★♡♥Ø".unicodeScalars)
        return String(self.unicodeScalars.filter(charactersToFilter.inverted.contains))
            .lowercased()
    }
}

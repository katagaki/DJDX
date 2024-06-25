//
//  CachedTrendData.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/25.
//

import Foundation
import OrderedCollections

struct CachedTrendData: Codable {
    var importGroupID: String
    var playType: IIDXPlayType
    var data: [Int: OrderedDictionary<String, Int>]
}

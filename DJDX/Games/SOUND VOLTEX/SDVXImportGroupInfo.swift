//
//  SDVXImportGroupInfo.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/05/31.
//

import Foundation

struct SDVXImportGroupInfo: Identifiable, Hashable {
    let id: String
    let date: Date
    let version: SDVXVersion?
}

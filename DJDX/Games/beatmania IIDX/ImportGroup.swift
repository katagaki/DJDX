//
//  ImportGroup.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/23.
//

import Foundation
import SwiftData

@Model
final class ImportGroup: @unchecked Sendable {
    var id: String = UUID().uuidString
    var importDate: Date = Date.distantPast
    @Relationship(deleteRule: .cascade, inverse: \IIDXSongRecord.importGroup) var iidxData: [IIDXSongRecord]?
    var iidxVersion: IIDXVersion?

    init(importDate: Date, iidxData: [IIDXSongRecord], iidxVersion: IIDXVersion) {
        self.importDate = importDate
        self.iidxData = iidxData
        self.iidxVersion = iidxVersion
    }
}

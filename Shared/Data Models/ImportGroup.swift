//
//  ImportGroup.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/23.
//

import Foundation
import SwiftData

@Model
final class ImportGroup {
    var id: String = UUID().uuidString
    var importDate: Date = Date.distantPast
    @Relationship(deleteRule: .cascade, inverse: \IIDXSongRecord.importGroup) var iidxData: [IIDXSongRecord]?
    var iidxVersion: IIDXVersion?

    init(importDate: Date, iidxData: [IIDXSongRecord], iidxVersion: IIDXVersion) {
        self.importDate = importDate
        self.iidxData = iidxData
        self.iidxVersion = iidxVersion
    }

    static func predicate(from startDate: Date) -> Predicate<ImportGroup> {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        let endDate: Date = Calendar.current.date(byAdding: components, to: startDate)!
        return #Predicate<ImportGroup> {
            $0.importDate >= startDate && $0.importDate <= endDate
        }
    }
}

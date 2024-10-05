//
//  ImportGroup.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/23.
//

import Foundation

func importGroups(from startDate: Date) -> Predicate<ImportGroup> {
    var components = DateComponents()
    components.day = 1
    components.second = -1
    let endDate: Date = Calendar.current.date(byAdding: components, to: startDate)!
    return #Predicate<ImportGroup> {
        $0.importDate >= startDate && $0.importDate <= endDate
    }
}

func iidxSongRecords(on playDataDate: Date) -> Predicate<IIDXSongRecord> {
    let startDate: Date = Calendar.current.startOfDay(for: playDataDate)
    var components = DateComponents()
    components.day = 1
    components.second = -1
    let endDate: Date = Calendar.current.date(byAdding: components, to: startDate)!
    return #Predicate<IIDXSongRecord> {
        if let importGroup = $0.importGroup {
            return importGroup.importDate >= startDate &&
            importGroup.importDate <= endDate
        } else {
            return false
        }
    }
}

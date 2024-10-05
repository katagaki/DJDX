//
//  DataFetcher.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/05.
//

import Foundation
import SwiftData

@ModelActor
actor DataFetcher {

    // MARK: Import Groups

    func importGroup(for selectedDate: Date) -> PersistentIdentifier? {
        let importGroupsForSelectedDate: [PersistentIdentifier] = (try? modelContext.fetchIdentifiers(
            FetchDescriptor<ImportGroup>(
                predicate: importGroups(from: selectedDate),
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        var importGroupIdentifier: PersistentIdentifier?
        if let importGroupForSelectedDate = importGroupsForSelectedDate.first {
            // Use selected date's import group
            importGroupIdentifier = importGroupForSelectedDate
        } else {
            // Use latest available import group
            let allImportGroups: [ImportGroup] = (try? modelContext.fetch(
                FetchDescriptor<ImportGroup>(
                    sortBy: [SortDescriptor(\.importDate, order: .forward)]
                )
            )) ?? []
            var importGroupClosestToTheSelectedDate: ImportGroup?
            for importGroup in allImportGroups {
                if importGroup.importDate <= selectedDate {
                    importGroupClosestToTheSelectedDate = importGroup
                } else {
                    break
                }
            }
            if let importGroupClosestToTheSelectedDate {
                importGroupIdentifier = importGroupClosestToTheSelectedDate.persistentModelID
            }
        }
        return importGroupIdentifier
    }
}

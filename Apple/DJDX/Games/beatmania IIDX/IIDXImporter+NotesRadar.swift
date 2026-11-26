import Foundation
import SQLite

extension IIDXImporter {

    @discardableResult
    func saveNotesRadar(_ radars: [IIDXPlayType: RadarData], version: IIDXVersion, on date: Date) -> Bool {
        guard let database = try? IIDXPlayDataDatabase.shared.getWriteConnection() else { return false }
        let col = IIDXPlayDataDatabase.self
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay),
              let group = try? database.pluck(col.importGroupTable
                .filter(col.igImportDate >= startOfDay.timeIntervalSince1970
                        && col.igImportDate < startOfNextDay.timeIntervalSince1970
                        && col.igIIDXVersion == version.rawValue)
                .order(col.igImportDate.desc)) else { return false }
        let groupID = group[col.igID]
        for (playType, radar) in radars {
            _ = try? database.run(col.notesRadarTable.insert(
                or: .replace,
                col.nrImportGroupID <- groupID,
                col.nrPlayType <- playType.rawValue,
                col.nrNotes <- radar.notes,
                col.nrChord <- radar.chord,
                col.nrPeak <- radar.peak,
                col.nrCharge <- radar.charge,
                col.nrScratch <- radar.scratch,
                col.nrSoflan <- radar.soflan
            ))
        }
        return true
    }
}

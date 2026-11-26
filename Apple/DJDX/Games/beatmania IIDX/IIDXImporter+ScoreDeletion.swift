import Foundation
import SQLite

extension IIDXImporter {

    func deleteImportGroup(id: String) {
        guard let database = try? IIDXPlayDataDatabase.current.getWriteConnection() else { return }
        let col = IIDXPlayDataDatabase.self
        try? database.transaction {
            try database.run(col.songRecordTable.filter(col.srImportGroupID == id).delete())
            try database.run(col.notesRadarTable.filter(col.nrImportGroupID == id).delete())
            try database.run(col.importGroupTable.filter(col.igID == id).delete())
        }
    }

    func deleteAllScoreData() {
        guard let database = try? IIDXPlayDataDatabase.current.getWriteConnection() else { return }
        let col = IIDXPlayDataDatabase.self
        try? database.transaction {
            try database.run(col.songRecordTable.delete())
            try database.run(col.notesRadarTable.delete())
            try database.run(col.importGroupTable.delete())
        }
    }
}

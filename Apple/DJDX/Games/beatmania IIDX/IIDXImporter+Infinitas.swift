import Foundation
import SQLite

extension IIDXImporter {
    func refreshInfinitasChartData() {
        let col = IIDXPlayDataDatabase.self
        guard let database = try? IIDXPlayDataDatabase.infinitas.getWriteConnection(),
              let rows = try? database.prepare(col.songRecordTable) else { return }
        let records = rows.map { ($0[col.srID], IIDXReader.songRecord(from: $0)) }
        guard !records.isEmpty else { return }
        let lookup = IIDXChartLookup.load()
        try? database.transaction {
            for (id, record) in records {
                lookup.enrich(record)
                try database.run(col.songRecordTable.filter(col.srID == id).update(
                    col.srBeginnerDifficulty <- record.beginnerScore.difficulty,
                    col.srBeginnerDJLevel <- record.beginnerScore.djLevel,
                    col.srNormalDifficulty <- record.normalScore.difficulty,
                    col.srNormalDJLevel <- record.normalScore.djLevel,
                    col.srHyperDifficulty <- record.hyperScore.difficulty,
                    col.srHyperDJLevel <- record.hyperScore.djLevel,
                    col.srAnotherDifficulty <- record.anotherScore.difficulty,
                    col.srAnotherDJLevel <- record.anotherScore.djLevel,
                    col.srLeggendariaDifficulty <- record.leggendariaScore.difficulty,
                    col.srLeggendariaDJLevel <- record.leggendariaScore.djLevel
                ))
            }
        }
    }
}

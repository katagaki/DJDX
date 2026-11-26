import Foundation
import SQLite

final class ChartNotesDatabase: Sendable {

    static let shared = ChartNotesDatabase()

    let databasePath: String

    static let noteTable = Table("ChartNote")
    static let nGame = SQLite.Expression<Int>("game")
    static let nTitle = SQLite.Expression<String>("title")
    static let nChart = SQLite.Expression<String>("chart")
    static let nText = SQLite.Expression<String>("text")
    static let nGreenNumber = SQLite.Expression<Int?>("greenNumber")
    static let nLaneCover = SQLite.Expression<Int?>("laneCover")
    static let nJudgmentOffset = SQLite.Expression<Int?>("judgmentOffset")
    static let nUpdatedAt = SQLite.Expression<Double>("updatedAt")

    init(fileName: String = "ChartNotes.db") {
        databasePath = SharedContainer.containerURL.appendingPathComponent(fileName).path
        createTablesIfNeeded()
    }

    private func createTablesIfNeeded() {
        do {
            let database = try Connection(databasePath)
            try database.run(Self.noteTable.create(ifNotExists: true) { table in
                table.column(Self.nGame)
                table.column(Self.nTitle)
                table.column(Self.nChart)
                table.column(Self.nText, defaultValue: "")
                table.column(Self.nGreenNumber)
                table.column(Self.nLaneCover)
                table.column(Self.nJudgmentOffset)
                table.column(Self.nUpdatedAt, defaultValue: 0.0)
                table.primaryKey(Self.nGame, Self.nTitle, Self.nChart)
            })
        } catch {
            debugPrint("Failed to create chart notes table: \(error)")
        }
    }

    func note(game: Game, title: String, chart: String) -> ChartNote {
        let empty = ChartNote(game: game, title: title, chart: chart)
        guard let database = try? Connection(databasePath, readonly: true),
              let row = try? database.pluck(Self.noteTable.filter(
                Self.nGame == game.rawValue && Self.nTitle == title && Self.nChart == chart
              )) else { return empty }
        return ChartNote(
            game: game, title: title, chart: chart,
            text: row[Self.nText],
            greenNumber: row[Self.nGreenNumber],
            laneCover: row[Self.nLaneCover],
            judgmentOffset: row[Self.nJudgmentOffset]
        )
    }

    func save(_ note: ChartNote) {
        guard let database = try? Connection(databasePath) else { return }
        database.busyTimeout = 5.0
        let row = Self.noteTable.filter(
            Self.nGame == note.game.rawValue && Self.nTitle == note.title && Self.nChart == note.chart
        )
        if note.isEmpty {
            _ = try? database.run(row.delete())
            return
        }
        _ = try? database.run(Self.noteTable.insert(or: .replace,
            Self.nGame <- note.game.rawValue,
            Self.nTitle <- note.title,
            Self.nChart <- note.chart,
            Self.nText <- note.text,
            Self.nGreenNumber <- note.greenNumber,
            Self.nLaneCover <- note.laneCover,
            Self.nJudgmentOffset <- note.judgmentOffset,
            Self.nUpdatedAt <- Date.now.timeIntervalSince1970
        ))
    }
}

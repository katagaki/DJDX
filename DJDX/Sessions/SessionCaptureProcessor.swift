import Foundation
import SQLite

actor SessionCaptureProcessor {
    static let shared = SessionCaptureProcessor()

    static let acceptableConfidence = 0.6

    private let db = PlaySessionsDatabase.shared
    private var songCandidates: [IIDXSongCandidate]?
    private var queue: [String] = []
    private var isDraining = false

    func submit(_ playID: String) {
        if !queue.contains(playID) { queue.append(playID) }
        Task { await drain() }
    }

    func reprocess(_ playID: String) {
        db.updatePlayState(id: playID, state: .pending)
        notify(playID)
        submit(playID)
    }

    func recover() async {
        for play in db.incompletePlays() where !queue.contains(play.id) {
            queue.append(play.id)
        }
        await drain()
    }

    private func drain() async {
        guard !isDraining, !queue.isEmpty else { return }
        isDraining = true
        await SessionBackgroundActivity.shared.begin()
        while !queue.isEmpty {
            let playID = queue.removeFirst()
            await process(playID)
        }
        isDraining = false
        await SessionBackgroundActivity.shared.end()
    }

    private func process(_ playID: String) async {
        guard let play = db.play(id: playID) else { return }
        db.updatePlayState(id: playID, state: .processing)
        notify(playID)

        guard let imageData = SessionImageStore.shared.data(for: play.rawImageFilename) else {
            fail(play, message: "Image unavailable")
            return
        }

        do {
            let lines = try await SessionTextRecognizer.recognize(imageData: imageData)
            let parse = IIDXResultParser.parse(lines: lines, songs: loadSongCandidates())
            play.apply(parse)
            play.processedAt = .now
            play.parseError = nil
            let acceptable = parse.matchedSongID != nil && parse.confidence >= Self.acceptableConfidence
            play.state = acceptable ? .done : .needsReview
            db.updatePlay(play)
            notify(playID)
        } catch {
            fail(play, message: error.localizedDescription)
        }
    }

    private func fail(_ play: CapturedPlay, message: String) {
        play.state = .failed
        play.parseError = message
        play.processedAt = .now
        db.updatePlay(play)
        notify(play.id)
    }

    private func loadSongCandidates() -> [IIDXSongCandidate] {
        if let songCandidates { return songCandidates }
        let loaded = Self.fetchSongCandidates()
        songCandidates = loaded
        return loaded
    }

    private nonisolated func notify(_ playID: String) {
        NotificationCenter.default.post(name: .capturedPlayDidChange, object: playID)
    }

    private static func fetchSongCandidates() -> [IIDXSongCandidate] {
        guard let database = try? IIDXPlayDataDatabase.shared.getReadConnection(),
              let rows = try? database.prepare(IIDXPlayDataDatabase.songTable) else {
            return []
        }
        return rows.map { row in
            let title = row[IIDXPlayDataDatabase.songTitle]
            return IIDXSongCandidate(id: row[IIDXPlayDataDatabase.songID], title: title, compact: title.compact)
        }
    }
}

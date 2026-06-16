import Foundation
import SQLite

actor SessionCaptureProcessor {
    static let shared = SessionCaptureProcessor()

    static let acceptableConfidence = 0.6

    private let database = PlaySessionsDatabase.shared
    private var songCandidates: [IIDXSongCandidate]?
    private var queue: [String] = []
    private var isDraining = false

    func submit(_ playID: String) {
        if !queue.contains(playID) { queue.append(playID) }
        Task { await drain() }
    }

    func reprocess(_ playID: String) {
        database.updatePlayState(id: playID, state: .pending)
        notify(playID)
        submit(playID)
    }

    func recover() async {
        for play in database.incompletePlays() where !queue.contains(play.id) {
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
        guard let play = database.play(id: playID) else { return }
        database.updatePlayState(id: playID, state: .processing)
        notify(playID)

        guard let imageData = SessionImageStore.shared.data(for: play.rawImageFilename) else {
            fail(play, message: "Image unavailable")
            return
        }

        do {
            let lines = try await SessionTextRecognizer.recognize(imageData: imageData)
            SessionImageStore.shared.writeOCRText(lines.map { $0.text }.joined(separator: "\n"), id: playID)
            let parse = IIDXResultParser.parse(lines: lines, songs: loadSongCandidates())
            play.apply(parse)
            play.processedAt = .now
            play.parseError = nil
            let acceptable = parse.matchedSongID != nil && parse.confidence >= Self.acceptableConfidence
            play.state = acceptable ? .done : .needsReview
            database.updatePlay(play)
            notify(playID)
        } catch {
            fail(play, message: error.localizedDescription)
        }
        await SessionLiveActivityController.shared.refresh(sessionID: play.sessionID)
    }

    private func fail(_ play: CapturedPlay, message: String) {
        play.state = .failed
        play.parseError = message
        play.processedAt = .now
        database.updatePlay(play)
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
        let columns = IIDXPlayDataDatabase.self
        guard let database = try? IIDXPlayDataDatabase.shared.getReadConnection(),
              let rows = try? database.prepare(columns.songRecordTable.order(columns.srID.desc)) else {
            return []
        }
        var seen = Set<String>()
        var candidates: [IIDXSongCandidate] = []
        for row in rows {
            let title = row[columns.srTitle]
            let playTypeRaw = row[columns.srPlayType]
            let key = title.compact + "|" + playTypeRaw
            guard !title.isEmpty, seen.insert(key).inserted else { continue }
            var difficulties: [IIDXLevel: Int] = [:]
            let pairs: [(IIDXLevel, Int)] = [
                (.beginner, row[columns.srBeginnerDifficulty]),
                (.normal, row[columns.srNormalDifficulty]),
                (.hyper, row[columns.srHyperDifficulty]),
                (.another, row[columns.srAnotherDifficulty]),
                (.leggendaria, row[columns.srLeggendariaDifficulty])
            ]
            for (level, value) in pairs where value > 0 {
                difficulties[level] = value
            }
            candidates.append(IIDXSongCandidate(
                id: row[columns.srID],
                title: title,
                compact: title.compact,
                playType: IIDXPlayType(rawValue: playTypeRaw) ?? .single,
                difficulties: difficulties
            ))
        }
        return candidates
    }
}

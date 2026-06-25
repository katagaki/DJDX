import Foundation
import SQLite

actor IIDXSessionCaptureProcessor {
    static let shared = IIDXSessionCaptureProcessor()

    static let acceptableConfidence = 0.6

    private let database = IIDXPlaySessionsDatabase.shared
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
        await IIDXSessionBackgroundActivity.shared.begin()
        while !queue.isEmpty {
            let playID = queue.removeFirst()
            await process(playID)
        }
        isDraining = false
        await IIDXSessionBackgroundActivity.shared.end()
    }

    private func process(_ playID: String) async {
        guard let play = database.play(id: playID) else { return }
        database.updatePlayState(id: playID, state: .processing)
        notify(playID)

        guard let imageData = IIDXSessionImageStore.shared.data(for: play.rawImageFilename) else {
            fail(play, message: "Image unavailable")
            return
        }

        let staged = IIDXLiveResultAccumulator.shared.takeStaged(for: playID)
        do {
            let photoRegions = try await IIDXResultReader.detect(imageData: imageData)
            let regions = merge(photoRegions, staged: staged)
            IIDXSessionImageStore.shared.writeRecognizedText(recognizedText(from: regions), id: playID)
            let parse = IIDXResultParser.heal(
                IIDXResultParser.parse(regions: regions, songs: loadSongCandidates())
            )
            play.apply(parse)
            play.processedAt = .now
            play.parseError = nil
            let recognitionFailed = regions.contains { $0.recognitionFailed }
            let acceptable = parse.matchedSongID != nil
                && parse.confidence >= Self.acceptableConfidence
                && !recognitionFailed
            play.state = acceptable ? .done : .needsReview
            database.updatePlay(play)
            notify(playID)
        } catch {
            fail(play, message: error.localizedDescription)
        }
        await IIDXSessionLiveActivityController.shared.refresh(sessionID: play.sessionID)
        await IIDXSessionLiveActivityController.shared.pushSessionInfoToWatch(sessionID: play.sessionID)
    }

    private func fail(_ play: IIDXCapturedPlay, message: String) {
        play.state = .failed
        play.parseError = message
        play.processedAt = .now
        database.updatePlay(play)
        notify(play.id)
    }

    private func merge(_ photo: [DetectedRegion], staged: [DetectedRegion]) -> [DetectedRegion] {
        guard !staged.isEmpty else { return photo }
        let songs = loadSongCandidates()
        let photoIdentity = IIDXLiveResultAccumulator.identityKey(
            IIDXResultParser.parse(regions: photo, songs: songs)
        )
        let stagedIdentity = IIDXLiveResultAccumulator.identityKey(
            IIDXResultParser.parse(regions: staged, songs: songs)
        )
        if let photoIdentity, let stagedIdentity, photoIdentity != stagedIdentity {
            return photo
        }
        var byLabel: [String: DetectedRegion] = [:]
        for region in photo { byLabel[region.label] = region }
        for region in staged {
            guard let existing = byLabel[region.label] else {
                byLabel[region.label] = region
                continue
            }
            if IIDXLiveResultAccumulator.score(region) > IIDXLiveResultAccumulator.score(existing) {
                byLabel[region.label] = region
            }
        }
        return Array(byLabel.values)
    }

    private static let titleRegionLabels: Set<String> = ["song_title", "song_artist"]

    private func recognizedText(from regions: [DetectedRegion]) -> RecognizedTextResult {
        func box(_ region: DetectedRegion) -> RecognizedTextBox {
            RecognizedTextBox(
                text: region.text.replacingOccurrences(of: "\n", with: " "),
                originX: region.box.minX, originY: region.box.minY,
                width: region.box.width, height: region.box.height
            )
        }
        return RecognizedTextResult(
            numeric: regions.filter { !Self.titleRegionLabels.contains($0.label) }.map(box),
            title: regions.filter { Self.titleRegionLabels.contains($0.label) }.map(box)
        )
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

    // Imported score records carry the user's own chart difficulties; BEMANIWiki
    // levels fill the gaps (and add songs never imported) so the parser can resolve
    // a chart's level from its difficulty name without relying on OCR.
    static func fetchSongCandidates() -> [IIDXSongCandidate] {
        var byKey: [String: IIDXSongCandidate] = [:]
        for candidate in fetchScoreSongCandidates() {
            byKey[key(for: candidate)] = candidate
        }
        for candidate in fetchBEMANIWikiCandidates() {
            let key = key(for: candidate)
            guard let existing = byKey[key] else {
                byKey[key] = candidate
                continue
            }
            var merged = existing.difficulties
            for (level, value) in candidate.difficulties where merged[level] == nil {
                merged[level] = value
            }
            byKey[key] = IIDXSongCandidate(
                id: existing.id, title: existing.title, compact: existing.compact,
                playType: existing.playType, difficulties: merged
            )
        }
        return Array(byKey.values)
    }

    private static func key(for candidate: IIDXSongCandidate) -> String {
        candidate.compact + "|" + candidate.playType.rawValue
    }
}

extension IIDXSessionCaptureProcessor {
    static func fetchScoreSongCandidates() -> [IIDXSongCandidate] {
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

    static func fetchBEMANIWikiCandidates() -> [IIDXSongCandidate] {
        let col = BEMANIWikiDatabase.self
        guard let database = try? BEMANIWikiDatabase.shared.getReadConnection(),
              let rows = try? database.prepare(col.songTable) else {
            return []
        }
        var candidates: [IIDXSongCandidate] = []
        for row in rows {
            let title = row[col.songTitle]
            guard !title.isEmpty else { continue }
            let identifier = row[col.songID]
            let single: [(IIDXLevel, Int?)] = [
                (.beginner, row[col.songSPBeginnerLevel]), (.normal, row[col.songSPNormalLevel]),
                (.hyper, row[col.songSPHyperLevel]), (.another, row[col.songSPAnotherLevel]),
                (.leggendaria, row[col.songSPLeggendariaLevel])
            ]
            let double: [(IIDXLevel, Int?)] = [
                (.normal, row[col.songDPNormalLevel]), (.hyper, row[col.songDPHyperLevel]),
                (.another, row[col.songDPAnotherLevel]), (.leggendaria, row[col.songDPLeggendariaLevel])
            ]
            if let candidate = makeCandidate(id: identifier, title: title, playType: .single, levels: single) {
                candidates.append(candidate)
            }
            if let candidate = makeCandidate(id: identifier, title: title, playType: .double, levels: double) {
                candidates.append(candidate)
            }
        }
        return candidates
    }

    private static func makeCandidate(
        id: Int64, title: String, playType: IIDXPlayType, levels: [(IIDXLevel, Int?)]
    ) -> IIDXSongCandidate? {
        var difficulties: [IIDXLevel: Int] = [:]
        for (level, value) in levels {
            if let value, value > 0 { difficulties[level] = value }
        }
        guard !difficulties.isEmpty else { return nil }
        return IIDXSongCandidate(
            id: id, title: title, compact: title.compact, playType: playType, difficulties: difficulties
        )
    }

    // Fill a chart's level on already-captured plays that have none, using the
    // freshly-loaded BEMANIWiki levels. Never overwrites an existing value.
    static func backfillDifficultiesFromBEMANIWiki() {
        let candidates = fetchBEMANIWikiCandidates()
        guard !candidates.isEmpty else { return }
        var lookup: [String: [IIDXLevel: Int]] = [:]
        for candidate in candidates {
            lookup[candidate.compact + "|" + candidate.playType.rawValue] = candidate.difficulties
        }
        let database = IIDXPlaySessionsDatabase.shared
        for session in database.allSessions() {
            for play in database.plays(forSession: session.id) where play.difficulty == 0 {
                guard play.level != .unknown,
                      let title = play.songTitle, !title.isEmpty,
                      let difficulties = lookup[title.compact + "|" + play.playType.rawValue],
                      let value = difficulties[play.level] else { continue }
                play.difficulty = value
                database.updatePlay(play)
            }
        }
    }
}

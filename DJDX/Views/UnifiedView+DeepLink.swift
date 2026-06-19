import SwiftUI

extension UnifiedView {
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "djdx",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        let queryItems = components.queryItems ?? []
        func value(for name: String) -> String? {
            queryItems.first { $0.name.lowercased() == name.lowercased() }?.value
        }

        switch url.host {
        case "update":
            guard value(for: "type")?.lowercased() == "datasource",
                  let id = value(for: "id"),
                  let source = ExternalDataSourceID.allCases.first(where: {
                      $0.rawValue.lowercased() == id.lowercased()
                  }) else {
                return
            }
            Task { await ExternalDataReloader.reload(source, iidxVersion: iidxVersion) }

        case "open":
            let type = value(for: "type")?.lowercased()
            let game = value(for: "game")?.lowercased()
            if type == "detail" {
                guard game == "iidx", let songName = value(for: "songName"), !songName.isEmpty else {
                    return
                }
                Task { await openIIDXScoreDetail(songName: songName) }
                return
            }
            if let game, let target = Self.game(named: game), target.isAvailable {
                navigationManager.popToRoot()
                selectedGame = target
            }

        case "session":
            guard value(for: "action")?.lowercased() == "capture" else { return }
            navigationManager.popToRoot()
            appMode = .sessions
            sessionStore.requestCapture()

        default:
            break
        }
    }

    static func game(named name: String) -> Game? {
        switch name {
        case "iidx", "iidxarcade", "beatmania": .iidxArcade
        case "sdvx", "soundvoltex": .soundVoltex
        case "polaris", "polarischord": .polarisChord
        case "ddr", "ddrworld", "dancedancerevolution": .danceDanceRevolution
        default: nil
        }
    }

    func openIIDXScoreDetail(songName: String) async {
        let reader = IIDXReader()
        guard let record = await resolveIIDXSongRecord(named: songName, using: reader) else {
            debugPrint("Deep link: no IIDX song record found for \(songName)")
            return
        }
        await MainActor.run {
            if selectedGame != .iidxArcade {
                selectedGame = .iidxArcade
            }
            navigationManager.popToRoot()
        }
        let level = highestDifficultyLevel(for: record)
        try? await Task.sleep(for: .milliseconds(150))
        await MainActor.run {
            navigationManager.push(ScoresPath.scoreViewer(songRecord: record, initialLevel: level))
        }
    }

    func highestDifficultyLevel(for record: IIDXSongRecord) -> IIDXLevel {
        let candidates: [(IIDXLevel, Int)] = [
            (.beginner, record.beginnerScore.difficulty),
            (.normal, record.normalScore.difficulty),
            (.hyper, record.hyperScore.difficulty),
            (.another, record.anotherScore.difficulty),
            (.leggendaria, record.leggendariaScore.difficulty)
        ]
        var best: (IIDXLevel, Int)?
        for candidate in candidates where candidate.1 != 0 {
            if best == nil || candidate.1 >= best!.1 {
                best = candidate
            }
        }
        return best?.0 ?? .all
    }

    func resolveIIDXSongRecord(named songName: String, using reader: IIDXReader) async -> IIDXSongRecord? {
        if let importGroup = await reader.importGroup(for: .now, version: iidxVersion) {
            let records = await reader.songRecords(for: importGroup.id, playType: playTypeToShow)
            if let exact = records.first(where: { $0.title.compact == songName.compact }) {
                return exact
            }
            if let fuzzy = records.first(where: { $0.title.localizedCaseInsensitiveContains(songName) }) {
                return fuzzy
            }
        }
        let matching = await reader.songRecordsForSong(title: songName)
        return matching.first { $0.playType == playTypeToShow } ?? matching.first
    }
}

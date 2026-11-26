import Foundation
import Observation

@MainActor
@Observable
final class IIDXSessionSongInfo {
    static let shared = IIDXSessionSongInfo()

    private(set) var metadata: [String: IIDXSongMetadata] = [:]
    private(set) var songs: [String: IIDXSong] = [:]
    private var hasLoaded: Bool = false
    private let reader = IIDXReader()

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        hasLoaded = true
        async let metadata = reader.songMetadata()
        async let songs = reader.songCompactTitles()
        self.metadata = await metadata
        self.songs = await songs
    }
}

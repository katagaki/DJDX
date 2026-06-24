import Foundation
import QuartzCore

final class IIDXLiveResultAccumulator: @unchecked Sendable {
    static let shared = IIDXLiveResultAccumulator()

    private struct Entry {
        var region: DetectedRegion
        var time: CFTimeInterval
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var identity: String?
    private var staged: [String: [DetectedRegion]] = [:]

    private let window: CFTimeInterval = 3.0

    func ingest(regions: [DetectedRegion], parse: IIDXResultParse, at time: CFTimeInterval) {
        lock.lock(); defer { lock.unlock() }
        let incoming = Self.identityKey(parse)
        if let incoming, incoming != identity {
            entries.removeAll()
            identity = incoming
        } else if identity == nil {
            identity = incoming
        }
        for region in regions where !region.text.isEmpty {
            if let existing = entries[region.label], Self.score(existing.region) > Self.score(region) {
                continue
            }
            entries[region.label] = Entry(region: region, time: time)
        }
    }

    func snapshot() -> [DetectedRegion] {
        lock.lock(); defer { lock.unlock() }
        let now = CACurrentMediaTime()
        return entries.values.filter { now - $0.time <= window }.map(\.region)
    }

    func clearLive() {
        lock.lock(); defer { lock.unlock() }
        entries.removeAll()
        identity = nil
    }

    func stage(_ regions: [DetectedRegion], for playID: String) {
        guard !regions.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        staged[playID] = regions
    }

    func takeStaged(for playID: String) -> [DetectedRegion] {
        lock.lock(); defer { lock.unlock() }
        return staged.removeValue(forKey: playID) ?? []
    }

    static func score(_ region: DetectedRegion) -> Float {
        region.recognitionFailed ? -1 : region.confidence
    }

    static func identityKey(_ parse: IIDXResultParse) -> String? {
        guard let id = parse.matchedSongID else { return nil }
        return "\(id)|\(parse.level)|\(parse.difficulty)|\(parse.playType)"
    }
}

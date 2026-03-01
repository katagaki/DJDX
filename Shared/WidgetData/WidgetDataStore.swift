//
//  WidgetDataStore.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import Foundation

final class WidgetDataStore: Sendable {
    static let shared = WidgetDataStore()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    private init() {
        try? FileManager.default.createDirectory(
            at: SharedContainer.widgetDataURL,
            withIntermediateDirectories: true
        )
    }

    // MARK: - File URLs

    private var radarURL: URL { SharedContainer.widgetDataURL.appendingPathComponent("radar.json") }
    private var clearTypeURL: URL { SharedContainer.widgetDataURL.appendingPathComponent("clearType.json") }
    private var djLevelURL: URL { SharedContainer.widgetDataURL.appendingPathComponent("djLevel.json") }
    private var towerURL: URL { SharedContainer.widgetDataURL.appendingPathComponent("tower.json") }
    private var qproImageURL: URL { SharedContainer.widgetDataURL.appendingPathComponent("Qpro.png") }

    // MARK: - Write (called by main app)

    func writeRadar(_ snapshot: WidgetRadarSnapshot) { write(snapshot, to: radarURL) }
    func writeClearType(_ snapshot: WidgetClearTypeSnapshot) { write(snapshot, to: clearTypeURL) }
    func writeDJLevel(_ snapshot: WidgetDJLevelSnapshot) { write(snapshot, to: djLevelURL) }
    func writeTower(_ snapshot: WidgetTowerSnapshot) { write(snapshot, to: towerURL) }
    func writeQproImage(_ imageData: Data) { try? imageData.write(to: qproImageURL, options: .atomic) }

    // MARK: - Read (called by widget extension)

    func readRadar() -> WidgetRadarSnapshot? { read(from: radarURL) }
    func readClearType() -> WidgetClearTypeSnapshot? { read(from: clearTypeURL) }
    func readDJLevel() -> WidgetDJLevelSnapshot? { read(from: djLevelURL) }
    func readTower() -> WidgetTowerSnapshot? { read(from: towerURL) }
    func readQproImage() -> Data? { try? Data(contentsOf: qproImageURL) }

    // MARK: - Private

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func read<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}

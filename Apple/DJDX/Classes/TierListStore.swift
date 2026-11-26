import Foundation
import Observation
import SwiftUI

enum TierListTier: String, CaseIterable, Codable, Identifiable {
    case tierS = "S"
    case tierA = "A"
    case tierB = "B"
    case tierC = "C"
    case tierD = "D"
    case tierE = "E"
    case tierF = "F"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .tierS: Color(red: 1.0, green: 0.5, blue: 0.5)
        case .tierA: Color(red: 1.0, green: 0.75, blue: 0.5)
        case .tierB: Color(red: 1.0, green: 0.87, blue: 0.5)
        case .tierC: Color(red: 1.0, green: 1.0, blue: 0.5)
        case .tierD: Color(red: 0.75, green: 1.0, blue: 0.5)
        case .tierE: Color(red: 0.5, green: 1.0, blue: 0.75)
        case .tierF: Color(red: 0.5, green: 0.75, blue: 1.0)
        }
    }
}

struct TierListKey: Hashable, Codable {
    var game: String
    var playType: String
    var level: String

    var storageKey: String { "\(game)/\(playType)/\(level)" }
}

struct TierList: Codable, Equatable {
    var tiers: [String: [String]] = [:]

    func charts(in tier: TierListTier) -> [String] {
        tiers[tier.rawValue] ?? []
    }

    func tier(of chartID: String) -> TierListTier? {
        TierListTier.allCases.first { charts(in: $0).contains(chartID) }
    }

    var isEmpty: Bool {
        tiers.values.allSatisfy(\.isEmpty)
    }

    mutating func remove(_ chartID: String) {
        for (tier, ids) in tiers {
            tiers[tier] = ids.filter { $0 != chartID }
        }
    }

    mutating func place(_ chartID: String, in tier: TierListTier?, before targetID: String? = nil) {
        remove(chartID)
        guard let tier else { return }
        var ids = charts(in: tier)
        if let targetID, let index = ids.firstIndex(of: targetID) {
            ids.insert(chartID, at: index)
        } else {
            ids.append(chartID)
        }
        tiers[tier.rawValue] = ids
    }
}

struct TierListShare: Codable, Identifiable {
    var version: Int = 1
    var game: String
    var playType: String
    var level: String
    var tiers: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case game = "g"
        case playType = "p"
        case level = "l"
        case tiers = "t"
    }

    var id: String { "\(key.storageKey)/\(code ?? "")" }

    var key: TierListKey { TierListKey(game: game, playType: playType, level: level) }

    init(key: TierListKey, list: TierList) {
        game = key.game
        playType = key.playType
        level = key.level
        tiers = list.tiers.filter { !$0.value.isEmpty }
    }

    var code: String? {
        guard let json = try? JSONEncoder().encode(self),
              let compressed = try? (json as NSData).compressed(using: .zlib) as Data else { return nil }
        return compressed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    var url: URL? {
        guard let code else { return nil }
        var components = URLComponents()
        components.scheme = "djdx"
        components.host = "tierlist"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url
    }

    static func decode(_ input: String) -> TierListShare? {
        var code = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: code), url.scheme == "djdx",
           let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value {
            code = value
        }
        code = code.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        code += String(repeating: "=", count: (4 - code.count % 4) % 4)
        guard let data = Data(base64Encoded: code),
              let json = try? (data as NSData).decompressed(using: .zlib) as Data,
              let share = try? JSONDecoder().decode(TierListShare.self, from: json) else { return nil }
        return share
    }
}

@MainActor
@Observable
final class TierListStore {

    static let shared = TierListStore()
    static let fileName = "TierLists.json"

    private struct Snapshot: Codable {
        var version: Int = 1
        var lists: [String: TierList] = [:]
    }

    private(set) var lists: [String: TierList] = [:]

    private var fileURL: URL {
        SharedContainer.containerURL.appendingPathComponent(Self.fileName)
    }

    init() {
        reload()
    }

    func reload() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            lists = [:]
            return
        }
        lists = snapshot.lists
    }

    func list(for key: TierListKey) -> TierList {
        lists[key.storageKey] ?? TierList()
    }

    func update(_ key: TierListKey, _ transform: (inout TierList) -> Void) {
        var list = list(for: key)
        transform(&list)
        lists[key.storageKey] = list.isEmpty ? nil : list
        save()
    }

    func replace(_ key: TierListKey, with list: TierList) {
        lists[key.storageKey] = list.isEmpty ? nil : list
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Snapshot(lists: lists)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

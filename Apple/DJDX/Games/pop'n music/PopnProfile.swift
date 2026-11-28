import Foundation

struct PopnProfile {
    var playerName: String?
    var popnClass: String?
    var popnClassIconURL: String?

    static func key(_ field: String, for version: PopnVersion) -> String {
        "PopnProfile.\(version.slug).\(field)"
    }

    static func load(for version: PopnVersion) -> PopnProfile {
        let defaults = UserDefaults.standard
        return PopnProfile(
            playerName: defaults.string(forKey: key("PlayerName", for: version)),
            popnClass: defaults.string(forKey: key("PopnClass", for: version)),
            popnClassIconURL: defaults.string(forKey: key("PopnClassIconURL", for: version))
        )
    }

    static func save(_ json: [String: Any], for version: PopnVersion) {
        let defaults = UserDefaults.standard
        for (field, jsonKey) in [("PlayerName", "name"), ("PopnClass", "popnClass"),
                                 ("PopnClassIconURL", "popnClassIcon")] {
            if let value = (json[jsonKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                defaults.set(value, forKey: key(field, for: version))
            }
        }
    }
}

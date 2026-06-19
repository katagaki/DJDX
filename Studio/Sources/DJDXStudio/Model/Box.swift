import Foundation

// One labelled region, normalised to [0,1], origin top-left — the shape
// training/labels/labels.json uses. `conf` rides along on predictions,
// `polygon` on skewed-quad boxes; both preserved on round-trip.
struct Box: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var cls: String
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var conf: Double?
    var polygon: [[Double]]?

    enum CodingKeys: String, CodingKey {
        case cls, x, y, w, h, conf, polygon
    }

    init(cls: String, x: Double, y: Double, w: Double, h: Double,
         conf: Double? = nil, polygon: [[Double]]? = nil) {
        self.cls = cls
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.conf = conf
        self.polygon = polygon
    }

    func normalised() -> Box {
        var b = self
        b.x = min(max(x, 0), 1)
        b.y = min(max(y, 0), 1)
        b.w = min(max(w, 0), 1 - b.x)
        b.h = min(max(h, 0), 1 - b.y)
        return b
    }
}

// {image_name: [Box, ...]} — same flat JSON object the Python tools use.
struct LabelSet: Codable, Sendable {
    var byImage: [String: [Box]]

    init(byImage: [String: [Box]] = [:]) { self.byImage = byImage }

    init(from decoder: Decoder) throws {
        byImage = try decoder.singleValueContainer().decode([String: [Box]].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(byImage)
    }
}

// {image_name: "AAA", ...} — DJ Level's per-image single-class labels, the shape
// scripts/prepare_djlevel_dataset.py reads. In memory the app keeps these as a
// single full-frame Box so the editor/undo/status code stays uniform; conversion
// happens at the load/save boundary (see AppModel).
struct ClassificationLabelSet: Codable, Sendable {
    var byImage: [String: String]

    init(byImage: [String: String] = [:]) { self.byImage = byImage }

    init(from decoder: Decoder) throws {
        byImage = try decoder.singleValueContainer().decode([String: String].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(byImage)
    }
}

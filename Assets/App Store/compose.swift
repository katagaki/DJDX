#!/usr/bin/env swift

import AppKit
import Foundation
import ImageIO
import SQLite3
import UniformTypeIdentifiers

// MARK: - Pages

let scriptFolder = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let templateFolder = scriptFolder.deletingLastPathComponent()
let languages = ["ja", "en"]
let captureLanguage = "ja"

enum Device: String {
    case iPhone
    case iPad

    var headlineArea: CGFloat {
        switch self {
        case .iPhone: 440
        case .iPad: 325
        }
    }
}

struct Page {
    let device: Device
    let template: String
    let name: String
    let captures: [String]
}

let pages: [Page] = [
    Page(device: .iPhone, template: "App Store - iPhone 1.pxd", name: "01-manage", captures: ["01-switcher"]),
    Page(device: .iPhone, template: "App Store - iPhone 2.pxd", name: "02-design", captures: ["02-song-detail"]),
    Page(device: .iPhone, template: "App Store - iPhone 3.pxd", name: "03-history", captures: ["03-import-history"]),
    Page(device: .iPhone, template: "App Store - iPhone 4.pxd", name: "04-analytics", captures: ["04-home", "04-sdvx"]),
    Page(device: .iPhone, template: "App Store - iPhone 5.pxd", name: "05-charts", captures: ["05-chart-viewer"]),
    Page(device: .iPhone, template: "App Store - iPhone 6.pxd", name: "06-integrations", captures: ["06-external-data"]),
    Page(device: .iPhone, template: "App Store - iPhone 7.pxd", name: "07-tower", captures: ["07-tower"])
]

let templates = [
    "App Store - iPhone 1.pxd", "App Store - iPhone 2.pxd", "App Store - iPhone 3.pxd", "App Store - iPhone 4.pxd",
    "App Store - iPhone 5.pxd", "App Store - iPhone 6.pxd", "App Store - iPhone 7.pxd",
    "App Store - iPad 1.pxd", "App Store - iPad 2.pxd"
]

// MARK: - Pixelmator Document

struct Layer {
    let id: Int
    let identifier: String
    let parent: String?
    let index: Int
    let type: Int
    let name: String
    let position: CGPoint
    let size: CGSize
    let scale: CGSize
    let angle: CGFloat
    let opacity: CGFloat
    let blendMode: CGBlendMode
    let flags: UInt8
    let info: [String: Data]

    var isVisible: Bool { flags & 0x01 != 0 }
    var clipsToLayerBelow: Bool { flags & 0x08 != 0 }
    var isMediaPlaceholder: Bool { name.hasPrefix("Media Placeholder") }
}

final class PixelmatorDocument {
    let folder: URL
    var canvasSize: CGSize = .zero
    var layers: [Layer] = []

    init(url: URL) throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComposeScreenshots-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", "-o", url.path, "-d", folder.path]
        try unzip.run()
        unzip.waitUntilExit()
        try load()
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    private func load() throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(folder.appendingPathComponent("metadata.info").path, &db,
                              SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw ComposeError("Could not open document metadata")
        }
        defer { sqlite3_close(db) }

        for (key, value) in query(db, "select key, value from document_info") where key == "size" {
            let width = value.subdata(in: 12..<20).withUnsafeBytes { $0.loadUnaligned(as: Int64.self) }
            let height = value.subdata(in: 20..<28).withUnsafeBytes { $0.loadUnaligned(as: Int64.self) }
            canvasSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        }

        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, "select id, identifier, parent_identifier, index_at_parent, type from document_layers",
                           -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let identifier = String(cString: sqlite3_column_text(statement, 1))
            let parent = sqlite3_column_text(statement, 2).map { String(cString: $0) }
            let index = Int(sqlite3_column_int(statement, 3))
            let type = Int(sqlite3_column_int(statement, 4))
            let info = Dictionary(
                query(db, "select key, value from layer_info where layer_id = \(id)"),
                uniquingKeysWith: { first, _ in first }
            )
            layers.append(Layer(
                id: id, identifier: identifier, parent: parent, index: index, type: type,
                name: info["name"].map(Self.string) ?? "",
                position: info["position"].map(Self.point) ?? .zero,
                size: info["size"].map { Self.size($0) } ?? .zero,
                scale: info["scale"].map { Self.size($0) } ?? CGSize(width: 1, height: 1),
                angle: info["angle"].map { Self.double($0) } ?? 0,
                opacity: info["opacity"].map { CGFloat($0[12]) / 100 } ?? 1,
                blendMode: info["blendMode"].map(Self.blendMode) ?? .normal,
                flags: info["flags"]?[12] ?? 1,
                info: info
            ))
        }
    }

    private func query(_ db: OpaquePointer?, _ sql: String) -> [(String, Data)] {
        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        var rows: [(String, Data)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let key = String(cString: sqlite3_column_text(statement, 0))
            let length = Int(sqlite3_column_bytes(statement, 1))
            let data = sqlite3_column_blob(statement, 1).map { Data(bytes: $0, count: length) } ?? Data()
            rows.append((key, data))
        }
        return rows
    }

    func children(of parent: String?) -> [Layer] {
        layers.filter { $0.parent == parent }.sorted { $0.index > $1.index }
    }

    func imageURL(for layer: Layer) -> URL {
        folder.appendingPathComponent("data/\(layer.identifier)-OriginalContentSource")
    }

    static func string(_ data: Data) -> String {
        let length = Int(data.subdata(in: 12..<16).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        return String(decoding: data.subdata(in: 16..<(16 + length)), as: UTF8.self)
    }

    static func double(_ data: Data, at offset: Int = 12) -> CGFloat {
        CGFloat(Double(bitPattern: data.subdata(in: offset..<(offset + 8))
            .withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.bigEndian))
    }

    static func blendMode(_ data: Data) -> CGBlendMode {
        switch String(decoding: data.subdata(in: 12..<16).reversed(), as: UTF8.self) {
        case "mul ": .multiply
        case "scrn": .screen
        case "over": .overlay
        case "dark": .darken
        case "lite": .lighten
        case "sLit": .softLight
        case "hLit": .hardLight
        case "colr": .color
        case "lum ": .luminosity
        default: .normal
        }
    }

    static func point(_ data: Data) -> CGPoint {
        CGPoint(x: double(data), y: double(data, at: 20))
    }

    static func size(_ data: Data) -> CGSize {
        CGSize(width: double(data), height: double(data, at: 20))
    }
}

struct ComposeError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// MARK: - Styles

struct ShapeStyle {
    struct Fill {
        let color: CGColor?
        let gradient: CGGradient?
        let start: CGPoint
        let end: CGPoint
    }
    struct Stroke {
        let color: CGColor
        let width: CGFloat
    }
    struct Shadow {
        let color: CGColor
        let blur: CGFloat
        let offset: CGSize
    }
    var fills: [Fill] = []
    var strokes: [Stroke] = []
    var shadows: [Shadow] = []

    init(json data: Data?, colorSpace: CGColorSpace) {
        guard let data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let style = root.last as? [String: Any] else { return }

        func entries(_ key: String) -> [[String: Any]] {
            (style[key] as? [[Any]] ?? []).compactMap { $0.last as? [String: Any] }
                .filter { ($0["E"] as? Int ?? 1) == 1 }
        }
        func color(_ value: Any?) -> CGColor? {
            guard let wrapper = value as? [Any], let body = wrapper.last as? [String: Any],
                  let components = body["c"] as? [Double] else { return nil }
            return CGColor(colorSpace: colorSpace, components: components.map { CGFloat($0) })
        }
        func point(_ value: Any?) -> CGPoint {
            guard let array = value as? [Double], array.count == 2 else { return .zero }
            return CGPoint(x: array[0], y: array[1])
        }

        for fill in entries("f") {
            if (fill["fT"] as? Int) == 1,
               let wrapper = fill["g"] as? [Any], let body = wrapper.last as? [String: Any],
               let stops = body["s"] as? [[Any]] {
                var colors: [CGColor] = []
                var locations: [CGFloat] = []
                for stop in stops {
                    guard let pair = stop.last as? [Any], let rgba = pair.first as? [Double],
                          let location = pair.last as? Double else { continue }
                    colors.append(CGColor(colorSpace: colorSpace, components: rgba.map { CGFloat($0) })!)
                    locations.append(CGFloat(location))
                }
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray,
                                          locations: locations)
                fills.append(Fill(color: nil, gradient: gradient,
                                  start: point(fill["gSP"]), end: point(fill["gEP"])))
            } else {
                fills.append(Fill(color: color(fill["c"]), gradient: nil, start: .zero, end: .zero))
            }
        }
        for stroke in entries("s") {
            guard let strokeColor = color(stroke["c"]) else { continue }
            strokes.append(Stroke(color: strokeColor, width: CGFloat(stroke["W"] as? Double ?? 1)))
        }
        for shadow in entries("S") {
            guard let base = color(shadow["c"]) else { continue }
            let opacity = CGFloat(shadow["o"] as? Double ?? 1)
            let angle = CGFloat(shadow["a"] as? Double ?? 0)
            let distance = CGFloat(shadow["d"] as? Double ?? 0)
            shadows.append(Shadow(color: base.copy(alpha: base.alpha * opacity)!,
                                  blur: CGFloat(shadow["b"] as? Double ?? 0),
                                  offset: CGSize(width: cos(angle) * distance, height: sin(angle) * distance)))
        }
    }
}

// MARK: - Renderer

final class Renderer {
    let document: PixelmatorDocument
    let media: [URL]
    let locale: String
    let headlineArea: CGFloat?
    let colorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
    private var mediaIndex = 0

    init(document: PixelmatorDocument, media: [URL], locale: String, headlineArea: CGFloat?) {
        self.document = document
        self.media = media
        self.locale = locale
        self.headlineArea = headlineArea
    }

    func render() throws -> CGImage {
        let size = document.canvasSize
        guard let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ComposeError("Could not create canvas") }
        context.interpolationQuality = .high
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        renderChildren(of: nil, in: context)
        guard let image = context.makeImage() else { throw ComposeError("Could not render canvas") }
        return image
    }

    private func isShown(_ layer: Layer) -> Bool {
        for suffix in [" EN", " JA"] where layer.name.hasSuffix(suffix) {
            return suffix == " \(locale.uppercased())"
        }
        return layer.isVisible
    }

    private func renderChildren(of parent: String?, in context: CGContext) {
        let children = document.children(of: parent)
        for (offset, layer) in children.enumerated() where isShown(layer) {
            context.saveGState()
            if layer.clipsToLayerBelow, offset > 0, let path = shapePath(for: children[offset - 1]) {
                context.addPath(path)
                context.clip(using: .evenOdd)
            }
            let isolated = layer.opacity < 1 || layer.blendMode != .normal
            if isolated {
                context.setAlpha(layer.opacity)
                context.setBlendMode(layer.blendMode)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                context.setAlpha(1)
                context.setBlendMode(.normal)
            }
            render(layer, in: context)
            if isolated { context.endTransparencyLayer() }
            context.restoreGState()
        }
    }

    private func render(_ layer: Layer, in context: CGContext) {
        switch layer.type {
        case 1: renderImage(layer, in: context)
        case 2: renderText(layer, in: context)
        case 3: renderShape(layer, in: context)
        case 4: renderChildren(of: layer.identifier, in: context)
        case 6: renderFillLayer(layer, in: context)
        default: break
        }
    }

    private func applyTransform(of layer: Layer, to context: CGContext) {
        context.translateBy(x: layer.position.x, y: layer.position.y)
        context.rotate(by: -layer.angle * .pi / 180)
    }

    private func renderImage(_ layer: Layer, in context: CGContext) {
        let drawSize = CGSize(width: layer.size.width * layer.scale.width,
                              height: layer.size.height * layer.scale.height)
        let url: URL
        if layer.isMediaPlaceholder, mediaIndex < media.count {
            url = media[mediaIndex]
            mediaIndex += 1
        } else {
            url = document.imageURL(for: layer)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            print("  Could not load image for layer \(layer.name)")
            return
        }
        context.saveGState()
        applyTransform(of: layer, to: context)
        let rect = CGRect(x: -drawSize.width / 2, y: -drawSize.height / 2,
                          width: drawSize.width, height: drawSize.height)
        context.clip(to: rect)
        context.draw(image, in: aspectFill(CGSize(width: image.width, height: image.height), in: rect))
        context.restoreGState()
    }

    private func aspectFill(_ size: CGSize, in rect: CGRect) -> CGRect {
        let scale = max(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }

    private func shapePath(for layer: Layer) -> CGPath? {
        guard layer.type == 3, let data = layer.info["shape-shapeData"],
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let container = json["versionSpecifiContainer"] as? [String: Any],
              let wrappers = container["pathCodableWrappers"] as? [[String: Any]] else { return nil }
        let path = CGMutablePath()
        let transform = CGAffineTransform(translationX: layer.position.x, y: layer.position.y)
            .rotated(by: -layer.angle * .pi / 180)
            .translatedBy(x: -layer.size.width / 2, y: -layer.size.height / 2)
        for wrapper in wrappers {
            guard let body = wrapper["versionSpecifiContainer"] as? [String: Any],
                  let shapes = body["shapePathUnkeyedContainer"] as? [[String: Any]] else { continue }
            for shape in shapes {
                guard let shapeBody = shape["versionSpecifiContainer"] as? [String: Any],
                      let geometry = Self.geometry(of: shapeBody) else { continue }
                let radiusContainer = (shapeBody["cornerRadius"] as? [String: Any])?["versionSpecifiContainer"]
                let radius = CGFloat((radiusContainer as? [String: Any])?["unifiedValue"] as? Double ?? 0)
                let rect = CGRect(x: geometry.center.x - geometry.size.width / 2,
                                  y: geometry.center.y - geometry.size.height / 2,
                                  width: geometry.size.width, height: geometry.size.height)
                let clamped = min(radius, rect.width / 2, rect.height / 2)
                path.addRoundedRect(in: rect, cornerWidth: clamped, cornerHeight: clamped,
                                    transform: transform)
            }
        }
        return path
    }

    private static func geometry(of shape: [String: Any]) -> (center: CGPoint, size: CGSize)? {
        var current: [String: Any]? = shape
        while let node = current {
            if let geometry = node["geometry"] as? [Any], let body = geometry.last as? [String: Any],
               let p = body["p"] as? [Double], let s = body["S"] as? [Double] {
                return (CGPoint(x: p[0], y: p[1]), CGSize(width: s[0], height: s[1]))
            }
            current = (node["super"] as? [String: Any])?["versionSpecifiContainer"] as? [String: Any]
        }
        return nil
    }

    private func renderShape(_ layer: Layer, in context: CGContext) {
        guard let path = shapePath(for: layer) else { return }
        let style = ShapeStyle(json: layer.info["styles-data"], colorSpace: colorSpace)
        let bounds = CGRect(x: -layer.size.width / 2, y: -layer.size.height / 2,
                            width: layer.size.width, height: layer.size.height)
        let toCanvas = CGAffineTransform(translationX: layer.position.x, y: layer.position.y)
            .rotated(by: -layer.angle * .pi / 180)

        context.saveGState()
        if let shadow = style.shadows.first {
            context.setShadow(offset: shadow.offset, blur: shadow.blur, color: shadow.color)
        }
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        for fill in style.fills {
            context.saveGState()
            context.addPath(path)
            context.clip(using: .evenOdd)
            if let gradient = fill.gradient {
                let start = CGPoint(x: bounds.minX + fill.start.x * bounds.width,
                                    y: bounds.minY + fill.start.y * bounds.height).applying(toCanvas)
                let end = CGPoint(x: bounds.minX + fill.end.x * bounds.width,
                                  y: bounds.minY + fill.end.y * bounds.height).applying(toCanvas)
                context.drawLinearGradient(gradient, start: start, end: end,
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            } else if let color = fill.color {
                context.setFillColor(color)
                context.fill(path.boundingBoxOfPath.insetBy(dx: -1, dy: -1))
            }
            context.restoreGState()
        }
        for stroke in style.strokes {
            context.addPath(path)
            context.setStrokeColor(stroke.color)
            context.setLineWidth(stroke.width)
            context.strokePath()
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private func renderFillLayer(_ layer: Layer, in context: CGContext) {
        guard let data = layer.info["effects-data"],
              let json = String(data: data, encoding: .utf8) else { return }
        var color = CGColor(colorSpace: colorSpace, components: [0.1547, 0.1547, 0.1547, 1])!
        if let codingData = Self.firstMatch(in: json, pattern: "\"CIFilterNSCodingData\":\"([^\"]+)\""),
           let archive = Data(base64Encoded: codingData.replacingOccurrences(of: "\\/", with: "/")),
           let plist = try? PropertyListSerialization.propertyList(from: archive, format: nil) as? [String: Any],
           let objects = plist["$objects"] as? [Any],
           let stop = objects.compactMap({ $0 as? Data })
               .compactMap({ try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] })
               .first(where: { $0["red"] != nil }) {
            color = CGColor(colorSpace: colorSpace, components: [
                CGFloat(stop["red"] as? Double ?? 0), CGFloat(stop["green"] as? Double ?? 0),
                CGFloat(stop["blue"] as? Double ?? 0), CGFloat(stop["alpha"] as? Double ?? 1)
            ])!
        }
        context.setFillColor(color)
        context.fill(CGRect(origin: .zero, size: document.canvasSize))
    }

    private static func firstMatch(in string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range(at: 1), in: string) else { return nil }
        return String(string[range])
    }

    private func renderText(_ layer: Layer, in context: CGContext) {
        guard let data = layer.info["text-stringData"],
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let container = (json["versionSpecifiContainer"] ?? json["versionSpecificContainer"])
                as? [String: Any],
              let encoded = container["stringNSCodingData"] as? String,
              let archive = Data(base64Encoded: encoded),
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: archive) else { return }
        unarchiver.requiresSecureCoding = false
        guard let source = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
                as? NSAttributedString else { return }

        let text = NSMutableAttributedString(string: source.string)
        source.enumerateAttributes(in: NSRange(location: 0, length: source.length)) { attributes, range, _ in
            var converted: [NSAttributedString.Key: Any] = [:]
            for (key, value) in attributes {
                switch key.rawValue {
                case "com.pixelmatorteam.textkit.attribute.font-style-data":
                    if let data = value as? Data,
                       let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
                       let body = array.last as? [String: Any],
                       let name = body["n"] as? String, let size = body["s"] as? Double {
                        converted[.font] = Self.font(named: name, size: CGFloat(size),
                                                     bold: (body["b"] as? Int) == 1)
                    }
                case "com.pixelmatorteam.textkit.attribute.color":
                    if let color = value as? NSColor { converted[.foregroundColor] = color.cgColor }
                case "com.pixelmatorteam.textkit.attribute.paragraph-style":
                    converted[.paragraphStyle] = value
                case "com.pixelmatorteam.textkit.attribute.character-spacing":
                    converted[.kern] = value
                default:
                    break
                }
            }
            text.addAttributes(converted, range: range)
        }

        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                         height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        context.textMatrix = .identity
        context.textPosition = .zero
        var placements: [(line: CTLine, origin: CGPoint)] = []
        var glyphBounds = CGRect.null
        let separators = CharacterSet(charactersIn: "\u{2028}\n")
        layoutManager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layoutManager.numberOfGlyphs)) {
            rect, _, _, glyphRange, _ in
            var range = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let string = text.string as NSString
            while range.length > 0,
                  let scalar = Unicode.Scalar(string.character(at: range.location + range.length - 1)),
                  separators.contains(scalar) {
                range.length -= 1
            }
            guard range.length > 0 else { return }
            let line = CTLineCreateWithAttributedString(text.attributedSubstring(from: range))
            let baseline = -(rect.minY + layoutManager.location(forGlyphAt: glyphRange.location).y)
            let image = CTLineGetImageBounds(line, context)
            let origin = CGPoint(x: -image.midX, y: baseline)
            placements.append((line, origin))
            glyphBounds = glyphBounds.union(image.offsetBy(dx: origin.x, dy: origin.y))
        }
        guard !glyphBounds.isNull else { return }

        let center: CGFloat
        if layer.name.hasPrefix("Headline"), let headlineArea {
            center = document.canvasSize.height - headlineArea / 2 - layer.position.y
        } else {
            center = 0
        }
        let insets = layer.info["text-insets"].map { PixelmatorDocument.size($0) } ?? .zero
        let fit = min(1, (layer.size.width - insets.width * 2) / glyphBounds.width)
        let shift = center / fit - glyphBounds.midY

        context.saveGState()
        applyTransform(of: layer, to: context)
        context.scaleBy(x: fit, y: fit)
        for placement in placements {
            context.textPosition = CGPoint(x: placement.origin.x, y: placement.origin.y + shift)
            CTLineDraw(placement.line, context)
        }
        context.restoreGState()
    }

    private static func font(named name: String, size: CGFloat, bold: Bool) -> NSFont {
        let roundedPrefix = "SFCompactRounded-"
        guard name.hasPrefix(roundedPrefix) else {
            return NSFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .bold)
        }
        let weights: [String: NSFont.Weight] = [
            "Ultralight": .ultraLight, "Thin": .thin, "Light": .light, "Regular": .regular,
            "Medium": .medium, "Semibold": .semibold, "Bold": .bold, "Heavy": .heavy, "Black": .black
        ]
        var weight = weights[String(name.dropFirst(roundedPrefix.count))] ?? .regular
        if bold, weight == .regular { weight = .bold }
        return .systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Main

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString,
                                                            1, nil) else {
        throw ComposeError("Could not write \(url.path)")
    }
    let opaque = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                           bytesPerRow: 0, space: image.colorSpace!,
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    opaque.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    CGImageDestinationAddImage(destination, opaque.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { throw ComposeError("Could not write \(url.path)") }
}

func captureURL(_ name: String, device: Device, language: String) -> URL {
    let localized = scriptFolder.appendingPathComponent("Raw/\(device.rawValue)/\(language)/\(name).png")
    if FileManager.default.fileExists(atPath: localized.path) { return localized }
    return scriptFolder.appendingPathComponent("Raw/\(device.rawValue)/\(captureLanguage)/\(name).png")
}

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func pixels(of image: CGImage, size: CGSize) -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: Int(size.width) * Int(size.height) * 4)
    let context = CGContext(data: &buffer, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                            bytesPerRow: Int(size.width) * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(origin: .zero, size: size))
    return buffer
}

func compose() throws {
    for page in pages {
        let document = try PixelmatorDocument(url: templateFolder.appendingPathComponent(page.template))
        for language in languages {
            let media = page.captures.map { captureURL($0, device: page.device, language: language) }
            let image = try Renderer(document: document, media: media, locale: language,
                                     headlineArea: page.device.headlineArea).render()
            let url = scriptFolder.appendingPathComponent("\(page.device.rawValue)/\(language)/\(page.name).png")
            try writePNG(image, to: url)
            print("Wrote \(page.device.rawValue)/\(language)/\(page.name).png")
        }
    }
}

func verify() throws {
    var failures = 0
    for template in templates {
        let document = try PixelmatorDocument(url: templateFolder.appendingPathComponent(template))
        guard let thumbnail = loadImage(document.folder.appendingPathComponent("QuickLook/Thumbnail.webp")) else {
            print("SKIP \(template): no thumbnail")
            continue
        }
        let rendered = try Renderer(document: document, media: [], locale: "en", headlineArea: nil).render()
        let size = CGSize(width: thumbnail.width, height: thumbnail.height)
        let expected = pixels(of: thumbnail, size: size)
        let actual = pixels(of: rendered, size: size)
        var total = 0
        var count = 0
        let headlineRows = Int(size.height * 0.15)
        for index in stride(from: headlineRows * Int(size.width) * 4, to: expected.count, by: 4) {
            for channel in 0..<3 {
                total += abs(Int(expected[index + channel]) - Int(actual[index + channel]))
                count += 1
            }
        }
        let difference = Double(total) / Double(count)
        let passed = difference < 6
        if !passed { failures += 1 }
        print("\(passed ? "PASS" : "FAIL") \(template): mean difference \(String(format: "%.2f", difference))")
    }
    for page in pages {
        for language in languages {
            let url = scriptFolder.appendingPathComponent("\(page.device.rawValue)/\(language)/\(page.name).png")
            guard let image = loadImage(url) else {
                print("SKIP \(page.device.rawValue)/\(language)/\(page.name).png: not composed")
                continue
            }
            let size = CGSize(width: image.width, height: image.height)
            let buffer = pixels(of: image, size: size)
            let width = Int(size.width)
            let area = Int(page.device.headlineArea)
            var rows: [Int] = []
            var minimumX = width
            var maximumX = 0
            for y in 0..<area {
                var lit = false
                for x in 0..<width where buffer[(y * width + x) * 4] > 200 {
                    lit = true
                    minimumX = min(minimumX, x)
                    maximumX = max(maximumX, x)
                }
                if lit { rows.append(y) }
            }
            guard let top = rows.first, let bottom = rows.last else { continue }
            let verticalOffset = abs(top - (area - 1 - bottom))
            let horizontalOffset = abs(Double(minimumX + maximumX) / 2 - Double(width) / 2)
            let passed = verticalOffset <= 3 && horizontalOffset <= 3
            if !passed { failures += 1 }
            print("\(passed ? "PASS" : "FAIL") \(page.device.rawValue)/\(language)/\(page.name).png: "
                  + "headline offset \(verticalOffset)px vertical, \(String(format: "%.1f", horizontalOffset))px horizontal")
        }
    }
    if failures > 0 { exit(1) }
}

do {
    if CommandLine.arguments.contains("--verify") {
        try verify()
    } else {
        try compose()
    }
} catch {
    print("Error: \(error)")
    exit(1)
}

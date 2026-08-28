import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

struct RecognizedTextBox: Codable, Sendable {
    let text: String
    let originX: Double
    let originY: Double
    let width: Double
    let height: Double
}

struct RecognizedTextResult: Codable, Sendable {
    var numeric: [RecognizedTextBox]
    var title: [RecognizedTextBox]
}

final class IIDXSessionImageStore: Sendable {
    static let shared = IIDXSessionImageStore()

    static let maxDimension: Int = 2048
    static let compressionQuality: Double = 0.8

    private let directory: URL

    private init() {
        directory = SharedContainer.containerURL
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    @discardableResult
    func write(_ imageData: Data, id: String) -> String {
        let filename = "\(id).heic"
        let encoded = Self.encode(imageData) ?? imageData
        try? encoded.write(to: url(for: filename), options: .atomic)
        return filename
    }

    static func encode(_ imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let output = NSMutableData()
        let type = (UTType.heic.identifier as CFString)
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    func data(for filename: String) -> Data? {
        try? Data(contentsOf: url(for: filename))
    }

    func image(for filename: String) -> UIImage? {
        guard let data = data(for: filename) else { return nil }
        return UIImage(data: data)
    }

    func writeRecognizedText(_ result: RecognizedTextResult, id: String) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: ocrJSONURL(id: id), options: .atomic)
    }

    func recognizedText(id: String) -> RecognizedTextResult? {
        guard let data = try? Data(contentsOf: ocrJSONURL(id: id)),
              let result = try? JSONDecoder().decode(RecognizedTextResult.self, from: data) else {
            return nil
        }
        return result
    }

    func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
        let id = (filename as NSString).deletingPathExtension
        try? FileManager.default.removeItem(at: ocrJSONURL(id: id))
    }

    private func ocrJSONURL(id: String) -> URL {
        directory.appendingPathComponent("\(id).ocr.json")
    }
}

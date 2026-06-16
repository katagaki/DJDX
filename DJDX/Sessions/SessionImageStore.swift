import Foundation
import UIKit

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

final class SessionImageStore: Sendable {
    static let shared = SessionImageStore()

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
        try? imageData.write(to: url(for: filename), options: .atomic)
        return filename
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

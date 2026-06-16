import Foundation
import UIKit

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

    func writeOCRText(_ text: String, id: String) {
        try? Data(text.utf8).write(to: ocrTextURL(id: id), options: .atomic)
    }

    func ocrText(id: String) -> String? {
        try? String(contentsOf: ocrTextURL(id: id), encoding: .utf8)
    }

    func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
        let id = (filename as NSString).deletingPathExtension
        try? FileManager.default.removeItem(at: ocrTextURL(id: id))
    }

    private func ocrTextURL(id: String) -> URL {
        directory.appendingPathComponent("\(id).ocr.txt")
    }
}

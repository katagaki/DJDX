import SwiftUI
import UIKit

struct SessionFileExportRequest: Identifiable {
    let id = UUID()
    let urls: [URL]
}

enum SessionFileExporter {
    static func exportURLs(for filenames: [String], date: Date) -> [URL] {
        let store = IIDXSessionImageStore.shared
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionExport-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let baseName = "DJDX \(formatter.string(from: date))"

        var urls: [URL] = []
        for (index, filename) in filenames.enumerated() {
            let source = store.url(for: filename)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = directory
                .appendingPathComponent("\(baseName) \(String(format: "%02d", index + 1)).heic")
            try? FileManager.default.removeItem(at: destination)
            guard (try? FileManager.default.copyItem(at: source, to: destination)) != nil else { continue }
            urls.append(destination)
        }
        return urls
    }
}

struct SessionDocumentExporter: UIViewControllerRepresentable {
    let urls: [URL]
    let onCompletion: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onCompletion: () -> Void

        init(onCompletion: @escaping () -> Void) {
            self.onCompletion = onCompletion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onCompletion()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion()
        }
    }
}

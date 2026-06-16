import Foundation
import ImageIO
import Vision

enum SessionTextRecognizerError: Error {
    case invalidImage
}

enum SessionTextRecognizer {

    static func recognize(imageData: Data) async throws -> [OCRLine] {
        try await withCheckedThrowingContinuation { continuation in
            guard let decoded = decodeImage(from: imageData) else {
                continuation.resume(throwing: SessionTextRecognizerError.invalidImage)
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines: [OCRLine] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRLine(text: candidate.string, box: observation.boundingBox)
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = preferredLanguages(for: request)

            let handler = VNImageRequestHandler(
                cgImage: decoded.image,
                orientation: decoded.orientation,
                options: [:]
            )
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func preferredLanguages(for request: VNRecognizeTextRequest) -> [String] {
        let desired = ["ja-JP", "ja", "en-US", "en-JP", "en"]
        let supported = Set((try? request.supportedRecognitionLanguages()) ?? [])
        var chosen: [String] = []
        var seenPrefixes = Set<String>()
        for language in desired where supported.contains(language) {
            let prefix = String(language.prefix(2))
            if seenPrefixes.insert(prefix).inserted {
                chosen.append(language)
            }
        }
        return chosen.isEmpty ? ["ja-JP"] : chosen
    }

    private static func decodeImage(
        from data: Data
    ) -> (image: CGImage, orientation: CGImagePropertyOrientation)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        return (image, orientation)
    }
}

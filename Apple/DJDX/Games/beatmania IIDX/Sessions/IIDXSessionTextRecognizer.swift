import Foundation
import ImageIO
import Vision

enum IIDXSessionTextRecognizerError: Error {
    case invalidImage
}

enum IIDXSessionTextRecognizer {

    static let titleLanguages = ["ja-JP", "ja", "en-US", "en"]
    static let numericLanguages = ["en-US", "en"]

    static func recognize(imageData: Data, languages: [String]) async throws -> [OCRLine] {
        guard let decoded = decodeImage(from: imageData) else {
            throw IIDXSessionTextRecognizerError.invalidImage
        }
        return try await recognize(cgImage: decoded.image,
                                   orientation: decoded.orientation,
                                   languages: languages)
    }

    static func recognize(cgImage: CGImage,
                          orientation: CGImagePropertyOrientation = .up,
                          languages: [String]) async throws -> [OCRLine] {
        try await withCheckedThrowingContinuation { continuation in
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
            request.recognitionLanguages = supportedLanguages(languages, request: request)

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
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

    private static func supportedLanguages(_ desired: [String],
                                           request: VNRecognizeTextRequest) -> [String] {
        let supported = Set((try? request.supportedRecognitionLanguages()) ?? [])
        var chosen: [String] = []
        var seenPrefixes = Set<String>()
        for language in desired where supported.contains(language) {
            let prefix = String(language.prefix(2))
            if seenPrefixes.insert(prefix).inserted {
                chosen.append(language)
            }
        }
        return chosen.isEmpty ? [desired.first ?? "en-US"] : chosen
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

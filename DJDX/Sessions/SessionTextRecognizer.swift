import Foundation
import Vision

enum SessionTextRecognizerError: Error {
    case invalidImage
}

enum SessionTextRecognizer {

    static func recognize(imageData: Data) async throws -> [OCRLine] {
        try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = cgImage(from: imageData) else {
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
            request.recognitionLanguages = ["en-US", "ja-JP"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

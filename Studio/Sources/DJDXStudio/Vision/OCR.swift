import Foundation
import Vision
import CoreGraphics

struct OCRRegion: Sendable {
    var text: String
    var confidence: Float
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

enum OCR {
    // Ports ocr_helper.swift: accurate text recognition, en + ja, no language
    // correction. Coords normalised to [0,1] with origin flipped to top-left.
    static func recognize(_ cgImage: CGImage) -> [OCRRegion] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "ja-JP"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        return (request.results ?? []).compactMap { obs in
            guard let top = obs.topCandidates(1).first else { return nil }
            let b = obs.boundingBox
            return OCRRegion(
                text: top.string,
                confidence: top.confidence,
                x: b.origin.x,
                y: 1.0 - b.origin.y - b.size.height,
                w: b.size.width,
                h: b.size.height
            )
        }
    }

    static func recognize(url: URL) -> [OCRRegion] {
        guard let cg = ImageDecoder.load(url) else { return [] }
        return recognize(cg)
    }
}

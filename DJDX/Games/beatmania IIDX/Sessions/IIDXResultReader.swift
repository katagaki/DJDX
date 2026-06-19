import CoreML
import ImageIO
import UIKit
import Vision

struct DetectedRegion: Sendable {
    let label: String
    let text: String
    let box: CGRect
    let confidence: Float
}

enum IIDXResultReaderError: Error {
    case modelUnavailable
    case invalidImage
}

private struct RawDetection: Sendable {
    let label: String
    let confidence: Float
    let box: CGRect
}

// The IIDXResultDetector Core ML model is an object detector: every class is a
// region on the result screen (song_title, score_now, dj_level_now, ...), not a
// value. Vision localizes each region, then per-region OCR reads the text.
enum IIDXResultReader {

    static let maxDimension: CGFloat = 2048.0

    private static let titleLabels: Set<String> = ["song_title", "song_artist"]

    // Pure-number fields routed to the digit model when it is available; the rest
    // (clear_type, difficulty_label, stage_label, dj_level) stay on Vision OCR.
    private static let digitLabels: Set<String> = [
        "score_now", "score_prev", "score_delta",
        "miss_count_now", "miss_count_prev", "miss_count_delta",
        "judge_pgreat", "judge_great", "judge_good", "judge_bad", "judge_poor",
        "notes_count", "combo_break"
    ]

    // Index order matches the model's "classes" metadata; used to recover a class
    // name when Vision reports a label as its numeric index rather than its name.
    private static let classNames = [
        "dj_level_now", "dj_level_prev", "clear_type_now", "clear_type_prev",
        "score_now", "score_prev", "score_delta", "miss_count_now", "miss_count_prev",
        "miss_count_delta", "pacemaker_aa", "judge_pgreat", "judge_great", "judge_good",
        "judge_bad", "judge_poor", "song_title", "song_artist", "difficulty_label",
        "notes_count", "stage_label", "combo_break"
    ]

    private static func className(for identifier: String) -> String {
        if let index = Int(identifier), classNames.indices.contains(index) {
            return classNames[index]
        }
        return identifier
    }

    nonisolated(unsafe) private static let vnModel: VNCoreMLModel? = {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        guard let detector = try? IIDXResultDetector(configuration: configuration) else { return nil }
        return try? VNCoreMLModel(for: detector.model)
    }()

    static func detect(imageData: Data) async throws -> [DetectedRegion] {
        guard let vnModel else { throw IIDXResultReaderError.modelUnavailable }
        guard let image = uprightCGImage(from: imageData, maxDimension: maxDimension) else {
            throw IIDXResultReaderError.invalidImage
        }

        let detections = bestPerLabel(try await runDetection(vnModel: vnModel, image: image))

        var regions: [DetectedRegion] = []
        for detection in detections {
            let text = await read(detection, in: image)
            regions.append(DetectedRegion(
                label: detection.label,
                text: text,
                box: detection.box,
                confidence: detection.confidence
            ))
        }
        return regions
    }

    private static func read(_ detection: RawDetection, in image: CGImage) async -> String {
        guard let crop = crop(detection.box, from: image) else { return "" }
        if detection.label == "dj_level_now" {
            return await IIDXRankRecognizer.classify(cgImage: crop) ?? ""
        }
        if titleLabels.contains(detection.label) {
            return await ocrText(crop, languages: IIDXSessionTextRecognizer.titleLanguages)
        }
        if digitLabels.contains(detection.label),
           let value = await IIDXDigitRecognizer.recognize(cgImage: crop) {
            return String(value)
        }
        return await ocrText(crop, languages: IIDXSessionTextRecognizer.numericLanguages)
    }

    // MARK: - Vision

    private static func runDetection(vnModel: VNCoreMLModel,
                                     image: CGImage) async throws -> [RawDetection] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: vnModel) { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let results = (request.results as? [VNRecognizedObjectObservation] ?? [])
                    .compactMap { observation -> RawDetection? in
                        guard let label = observation.labels.first else { return nil }
                        return RawDetection(label: className(for: label.identifier),
                                            confidence: label.confidence,
                                            box: observation.boundingBox)
                    }
                continuation.resume(returning: results)
            }
            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func bestPerLabel(_ detections: [RawDetection]) -> [RawDetection] {
        var best: [String: RawDetection] = [:]
        for detection in detections {
            if let existing = best[detection.label], existing.confidence >= detection.confidence {
                continue
            }
            best[detection.label] = detection
        }
        return Array(best.values)
    }

    // MARK: - Per-region OCR

    private static func ocrText(_ crop: CGImage, languages: [String]) async -> String {
        let lines = (try? await IIDXSessionTextRecognizer.recognize(cgImage: crop, languages: languages)) ?? []
        // Headline value first: a field's own value is rendered larger than any
        // neighbouring delta/column that bleeds into the crop.
        return lines
            .sorted { $0.box.height > $1.box.height }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func crop(_ box: CGRect, from image: CGImage) -> CGImage? {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let padX = box.width * 0.06, padY = box.height * 0.10
        let minX = max(0, (box.minX - padX)) * width
        let maxX = min(1, (box.maxX + padX)) * width
        // Vision boxes use a bottom-left origin; CGImage cropping uses top-left.
        let minY = max(0, (1.0 - box.maxY - padY)) * height
        let maxY = min(1, (1.0 - box.minY + padY)) * height
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).integral
        guard rect.width >= 1, rect.height >= 1 else { return nil }
        return image.cropping(to: rect)
    }

    // MARK: - Image

    private static func uprightCGImage(from data: Data, maxDimension: CGFloat) -> CGImage? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.cgImage
    }
}

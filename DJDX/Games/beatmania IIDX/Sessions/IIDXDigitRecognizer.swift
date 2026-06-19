import CoreGraphics
import CoreML
import Vision

// Optional second-stage model: a 0–9 object detector (YOLO → Core ML, exported by
// DJDX PEAK Studio) that reads the IIDX LED number font Vision OCR cannot. It runs
// on the numeric field crops the result detector already isolates, sorts the digit
// boxes left-to-right, and assembles the value.
//
// Inert until IIDXDigitsDetector.mlpackage is added to the target — the model is
// loaded by bundle name at runtime, so the build never depends on its presence and
// the pipeline transparently falls back to Vision OCR while it is absent. Digit
// classes are "0"…"9"; any non-digit class (e.g. "minus"/"plus") is ignored.
enum IIDXDigitRecognizer {

    static let modelName = "IIDXDigitsDetector"
    static let confidenceThreshold: Float = 0.25

    nonisolated(unsafe) private static let vnModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else { return nil }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        guard let model = try? MLModel(contentsOf: url, configuration: configuration) else { return nil }
        return try? VNCoreMLModel(for: model)
    }()

    static var isAvailable: Bool { vnModel != nil }

    static func recognize(cgImage: CGImage) async -> Int? {
        guard let vnModel else { return nil }
        let digits = ((try? await run(vnModel: vnModel, image: cgImage)) ?? [])
            .filter { $0.confidence >= confidenceThreshold }
            .sorted { $0.minX < $1.minX }
            .compactMap { Int($0.identifier) }
            .filter { (0...9).contains($0) }
        guard !digits.isEmpty else { return nil }
        return Int(digits.map(String.init).joined())
    }

    private struct DigitBox: Sendable {
        let identifier: String
        let confidence: Float
        let minX: CGFloat
    }

    private static func run(vnModel: VNCoreMLModel, image: CGImage) async throws -> [DigitBox] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: vnModel) { request, error in
                if let error { continuation.resume(throwing: error); return }
                let results = (request.results as? [VNRecognizedObjectObservation] ?? [])
                    .compactMap { observation -> DigitBox? in
                        guard let label = observation.labels.first else { return nil }
                        return DigitBox(identifier: label.identifier,
                                        confidence: label.confidence,
                                        minX: observation.boundingBox.minX)
                    }
                continuation.resume(returning: results)
            }
            // Letterbox (preserve aspect): the model trains on letterboxed crops,
            // and numeric fields are extreme-aspect strips that .scaleFill would
            // stretch into unreadable rows of "1"s.
            request.imageCropAndScaleOption = .scaleFit
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
}

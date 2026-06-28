import CoreGraphics
import CoreML
import Vision

enum IIDXRankRecognizer {

    static let modelName = "IIDXRankClassifier"
    static let confidenceThreshold: Float = 0.5

    nonisolated(unsafe) private static let vnModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else { return nil }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        guard let model = try? MLModel(contentsOf: url, configuration: configuration) else { return nil }
        return try? VNCoreMLModel(for: model)
    }()

    static var isAvailable: Bool { vnModel != nil }

    static func classify(cgImage: CGImage) async -> String? {
        guard let vnModel else { return nil }
        guard let prediction = try? await run(vnModel: vnModel, image: cgImage),
              prediction.confidence >= confidenceThreshold else { return nil }
        return prediction.identifier
    }

    private struct Prediction: Sendable {
        let identifier: String
        let confidence: Float
    }

    private static func run(vnModel: VNCoreMLModel, image: CGImage) async throws -> Prediction? {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: vnModel) { request, error in
                if let error { continuation.resume(throwing: error); return }
                guard let top = (request.results as? [VNClassificationObservation])?.first else {
                    continuation.resume(returning: nil); return
                }
                continuation.resume(returning: Prediction(identifier: top.identifier, confidence: top.confidence))
            }
            request.imageCropAndScaleOption = .centerCrop
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

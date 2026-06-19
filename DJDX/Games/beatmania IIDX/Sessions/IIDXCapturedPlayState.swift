import Foundation

enum IIDXCapturedPlayState: String, Codable {
    case pending
    case processing
    case done
    case needsReview
    case failed

    var isTerminal: Bool {
        switch self {
        case .done, .needsReview, .failed: true
        case .pending, .processing: false
        }
    }
}

enum IIDXCapturedPlaySource: String, Codable {
    case camera
    case picker
}

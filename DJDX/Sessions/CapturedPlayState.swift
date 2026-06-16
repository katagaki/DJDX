import Foundation

enum CapturedPlayState: String, Codable {
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

enum CapturedPlaySource: String, Codable {
    case camera
    case picker
}

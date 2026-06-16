import Foundation

@Observable
@MainActor
final class WebImporterLoadingState {
    enum Phase {
        case connecting
        case loading
    }

    var phase: Phase = .connecting

    var label: LocalizedStringResource {
        switch phase {
        case .connecting: return "Shared.Connecting"
        case .loading: return "Shared.Loading"
        }
    }
}

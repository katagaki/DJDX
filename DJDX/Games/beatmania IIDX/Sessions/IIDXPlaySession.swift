import Foundation

final class IIDXPlaySession: Identifiable, @unchecked Sendable {
    var id: String = UUID().uuidString
    var game: Game = .iidxArcade
    var startDate: Date = .now
    var endDate: Date?
    var title: String?
    var venue: String?
    var workoutUUID: String?
    var liveActivityID: String?
    var notes: String?

    init(id: String = UUID().uuidString,
         game: Game = .iidxArcade,
         startDate: Date = .now,
         endDate: Date? = nil,
         title: String? = nil,
         venue: String? = nil,
         workoutUUID: String? = nil,
         liveActivityID: String? = nil,
         notes: String? = nil) {
        self.id = id
        self.game = game
        self.startDate = startDate
        self.endDate = endDate
        self.title = title
        self.venue = venue
        self.workoutUUID = workoutUUID
        self.liveActivityID = liveActivityID
        self.notes = notes
    }

    var isActive: Bool { endDate == nil }

    var duration: TimeInterval {
        (endDate ?? .now).timeIntervalSince(startDate)
    }
}

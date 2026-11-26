import Foundation
import SwiftUI

enum AnalyticsGoalKind: String, Codable, CaseIterable, Hashable {
    case rating
    case clearCount
    case gradeCount

    static func available(for game: Game) -> [AnalyticsGoalKind] {
        switch game {
        case .soundVoltex, .danceDanceRevolution: [.rating, .clearCount, .gradeCount]
        case .iidxArcade, .iidxInfinitas: [.clearCount, .gradeCount]
        case .polarisChord, .gitadora: []
        }
    }

    func titleKey(for game: Game) -> LocalizedStringKey {
        switch self {
        case .rating: game == .danceDanceRevolution ? "Goals.Kind.FlareSkill" : "Goals.Kind.Volforce"
        case .clearCount: "Goals.Kind.ClearCount"
        case .gradeCount: game.isIIDXFamily ? "Goals.Kind.DJLevelCount" : "Goals.Kind.GradeCount"
        }
    }
}

struct AnalyticsGoal: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var game: Game
    var kind: AnalyticsGoalKind
    var playStyle: String = ""
    var level: Int = 0
    var threshold: String = ""
    var target: Double
    var startDate: Date = .now
    var startValue: Double?
    var deadline: Date

    var isRating: Bool { kind == .rating }

    var title: String {
        switch kind {
        case .rating:
            return game == .danceDanceRevolution ? "FLARE SKILL" : "VOLFORCE"
        case .clearCount, .gradeCount:
            let levelText = level > 0 ? "LEVEL \(level) " : ""
            return levelText + AnalyticsGoal.thresholdDisplay(threshold, kind: kind, game: game)
        }
    }

    var subtitle: String? {
        switch game {
        case .iidxArcade, .iidxInfinitas:
            return IIDXPlayType(rawValue: playStyle)?.displayName()
        case .danceDanceRevolution:
            return DDRPlayStyle(rawValue: playStyle)?.abbreviation
        default:
            return nil
        }
    }

    func formatted(_ value: Double) -> String {
        if kind == .rating && game == .soundVoltex {
            return String(format: "%.2f", value)
        }
        return String(Int(value.rounded()))
    }

    static func thresholdOptions(kind: AnalyticsGoalKind, game: Game) -> [String] {
        switch (kind, game) {
        case (.clearCount, .iidxArcade), (.clearCount, .iidxInfinitas):
            return Array(IIDXClearType.ascending.dropFirst(2).map(\.rawValue).reversed())
        case (.gradeCount, .iidxArcade), (.gradeCount, .iidxInfinitas):
            return Array(IIDXDJLevel.sortedStrings.reversed())
        case (.clearCount, .soundVoltex):
            return SDVXClearType.sortedStringsWithoutNoPlay.filter { $0 != SDVXClearType.played.rawValue }
        case (.gradeCount, .soundVoltex):
            return SDVXGrade.sortedStrings
        case (.clearCount, .danceDanceRevolution):
            return DDRSongRecord.clearLampOrder.filter { $0 != "fail" }
        case (.gradeCount, .danceDanceRevolution):
            return DDRSongRecord.rankOrder
        default:
            return []
        }
    }

    static func levelOptions(for game: Game) -> [Int] {
        switch game {
        case .iidxArcade, .iidxInfinitas: Array(1...12)
        case .soundVoltex: Array(1...20)
        case .danceDanceRevolution: Array(1...19)
        case .polarisChord, .gitadora: []
        }
    }

    static func thresholdDisplay(_ threshold: String, kind: AnalyticsGoalKind, game: Game) -> String {
        guard game == .danceDanceRevolution else { return threshold }
        switch kind {
        case .clearCount:
            switch threshold {
            case "marv": return "MFC"
            case "perf": return "PFC"
            case "great": return "GFC"
            case "good": return "FC"
            case "li4clear": return "LIFE4"
            default: return threshold.uppercased()
            }
        case .gradeCount:
            return DDRSongRecord.rankDisplay(forStem: threshold)
        case .rating:
            return threshold
        }
    }
}

enum AnalyticsGoalStatus: Hashable {
    case achieved
    case ahead
    case onPace
    case behind
    case missed
    case notStarted

    var titleKey: LocalizedStringKey {
        switch self {
        case .achieved: "Goals.Status.Achieved"
        case .ahead: "Goals.Status.Ahead"
        case .onPace: "Goals.Status.OnPace"
        case .behind: "Goals.Status.Behind"
        case .missed: "Goals.Status.Missed"
        case .notStarted: "Goals.Status.NotStarted"
        }
    }

    var color: Color {
        switch self {
        case .achieved: .yellow
        case .ahead: .green
        case .onPace: .blue
        case .behind: .orange
        case .missed: .red
        case .notStarted: .gray
        }
    }

    var systemImage: String {
        switch self {
        case .achieved: "trophy.fill"
        case .ahead: "hare.fill"
        case .onPace: "checkmark.circle.fill"
        case .behind: "tortoise.fill"
        case .missed: "xmark.circle.fill"
        case .notStarted: "hourglass"
        }
    }
}

struct AnalyticsGoalPoint: Hashable, Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct AnalyticsGoalProgress: Hashable, Identifiable {
    let goal: AnalyticsGoal
    let history: [AnalyticsGoalPoint]
    var now: Date = .now

    var id: UUID { goal.id }

    var baseline: Double {
        goal.startValue ?? historicalBaseline
    }

    var historicalBaseline: Double {
        history.last(where: { $0.date <= goal.startDate })?.value ?? history.first?.value ?? 0.0
    }

    var current: Double {
        history.last?.value ?? baseline
    }

    var timeFraction: Double {
        let total = goal.deadline.timeIntervalSince(goal.startDate)
        guard total > 0 else { return 1.0 }
        return min(max(now.timeIntervalSince(goal.startDate) / total, 0.0), 1.0)
    }

    var expected: Double {
        expected(at: now)
    }

    var latestUpdate: AnalyticsGoalPoint? {
        guard let latest = history.last,
              latest.date > goal.startDate || latest.value != baseline else { return nil }
        return AnalyticsGoalPoint(date: max(latest.date, goal.startDate), value: latest.value)
    }

    func expected(at date: Date) -> Double {
        let total = goal.deadline.timeIntervalSince(goal.startDate)
        guard total > 0 else { return goal.target }
        let fraction = min(max(date.timeIntervalSince(goal.startDate) / total, 0.0), 1.0)
        return baseline + (goal.target - baseline) * fraction
    }

    var progressFraction: Double {
        let span = goal.target - baseline
        guard span > 0 else { return current >= goal.target ? 1.0 : 0.0 }
        return min(max((current - baseline) / span, 0.0), 1.0)
    }

    var remaining: Double {
        max(goal.target - current, 0.0)
    }

    var daysLeft: Int {
        max(Calendar.current.dateComponents([.day], from: now, to: goal.deadline).day ?? 0, 0)
    }

    var status: AnalyticsGoalStatus {
        if current >= goal.target { return .achieved }
        if now >= goal.deadline { return .missed }
        guard let latestUpdate else { return .notStarted }
        let gained = latestUpdate.value - baseline
        guard gained > 0 else { return .behind }
        let required = expected(at: latestUpdate.date) - baseline
        guard required > 0 else { return .ahead }
        let ratio = gained / required
        if ratio >= 1.15 { return .ahead }
        if ratio >= 0.9 { return .onPace }
        return .behind
    }
}

enum AnalyticsGoalStore {
    static let key = "Analytics.Goals"

    static func load() -> [AnalyticsGoal] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let goals = try? JSONDecoder().decode([AnalyticsGoal].self, from: data) else { return [] }
        return goals
    }

    static func save(_ goals: [AnalyticsGoal]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(goals), forKey: key)
        NotificationCenter.default.post(name: .analyticsGoalsDidChange, object: nil)
    }

    static func upsert(_ goal: AnalyticsGoal) {
        var goals = load()
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
        } else {
            goals.append(goal)
        }
        save(goals)
    }

    static func recordStartValues(_ values: [UUID: Double]) {
        var goals = load()
        var didChange = false
        for index in goals.indices where goals[index].startValue == nil {
            if let value = values[goals[index].id] {
                goals[index].startValue = value
                didChange = true
            }
        }
        if didChange { save(goals) }
    }

    static func delete(_ id: UUID) {
        save(load().filter { $0.id != id })
    }
}

extension Notification.Name {
    static let analyticsGoalsDidChange = Notification.Name("DJDX.AnalyticsGoalsDidChange")
}

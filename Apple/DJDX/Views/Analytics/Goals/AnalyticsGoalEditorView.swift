import SwiftUI

struct AnalyticsGoalEditorView: View {

    @Environment(\.dismiss) var dismiss

    let game: Game
    let existingGoal: AnalyticsGoal?

    @State var kind: AnalyticsGoalKind
    @State var playStyle: String
    @State var level: Int
    @State var threshold: String
    @State var target: Double
    @State var deadline: Date

    init(goal: AnalyticsGoal?, game: Game, playStyle: String) {
        self.game = game
        self.existingGoal = goal
        let kind = goal?.kind ?? AnalyticsGoalKind.available(for: game).first ?? .clearCount
        _kind = State(initialValue: kind)
        _playStyle = State(initialValue: goal?.playStyle ?? playStyle)
        _level = State(initialValue: goal?.level ?? (AnalyticsGoal.levelOptions(for: game).last ?? 0))
        _threshold = State(initialValue: goal?.threshold
                           ?? Self.defaultThreshold(kind: kind, game: game))
        _target = State(initialValue: goal?.target ?? (kind == .rating ? 0.0 : 10.0))
        _deadline = State(initialValue: goal?.deadline
                          ?? Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now)
    }

    static func defaultThreshold(kind: AnalyticsGoalKind, game: Game) -> String {
        let options = AnalyticsGoal.thresholdOptions(kind: kind, game: game)
        switch (kind, game) {
        case (.clearCount, .iidxArcade), (.clearCount, .iidxInfinitas):
            return IIDXClearType.hardClear.rawValue
        case (.gradeCount, .iidxArcade), (.gradeCount, .iidxInfinitas):
            return IIDXDJLevel.djAA.rawValue
        default:
            return options.first ?? ""
        }
    }

    var playStyles: [(value: String, label: String)] {
        switch game {
        case .iidxArcade, .iidxInfinitas:
            [(IIDXPlayType.single.rawValue, "SP"), (IIDXPlayType.double.rawValue, "DP")]
        case .danceDanceRevolution:
            [(DDRPlayStyle.single.rawValue, "SINGLE"), (DDRPlayStyle.double.rawValue, "DOUBLE")]
        default:
            []
        }
    }

    var isValid: Bool {
        target > 0 && (kind == .rating || !threshold.isEmpty) && deadline > .now
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    let kinds = AnalyticsGoalKind.available(for: game)
                    if kinds.count > 1 {
                        Picker("Goals.Kind", selection: $kind) {
                            ForEach(kinds, id: \.self) { kind in
                                Text(kind.titleKey(for: game)).tag(kind)
                            }
                        }
                    }
                    if !playStyles.isEmpty {
                        Picker("Shared.PlayType", selection: $playStyle) {
                            ForEach(playStyles, id: \.value) { style in
                                Text(verbatim: style.label).tag(style.value)
                            }
                        }
                    }
                    if kind != .rating {
                        Picker("Goals.Level", selection: $level) {
                            Text("Goals.Level.All").tag(0)
                            ForEach(AnalyticsGoal.levelOptions(for: game), id: \.self) { level in
                                Text(verbatim: "☆\(level)").tag(level)
                            }
                        }
                        Picker(kind == .clearCount ? "Goals.ClearType" : "Goals.Grade", selection: $threshold) {
                            ForEach(AnalyticsGoal.thresholdOptions(kind: kind, game: game), id: \.self) { option in
                                Text(verbatim: AnalyticsGoal.thresholdDisplay(option, kind: kind, game: game))
                                    .tag(option)
                            }
                        }
                    }
                } footer: {
                    if kind != .rating {
                        Text("Goals.Threshold.Footer")
                    } else if game == .danceDanceRevolution {
                        Text("Goals.FlareSkill.Footer")
                    }
                }
                Section {
                    HStack {
                        Text("Goals.Target")
                        Spacer()
                        TextField("Goals.Target", value: $target,
                                  format: kind == .rating && game == .soundVoltex
                                  ? .number.precision(.fractionLength(0...3))
                                  : .number.precision(.fractionLength(0)))
                        .keyboardType(kind == .rating && game == .soundVoltex ? .decimalPad : .numberPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                    }
                    DatePicker("Goals.Deadline", selection: $deadline,
                               in: Date.now.addingTimeInterval(86400)..., displayedComponents: .date)
                }
            }
            .navigationTitle(existingGoal == nil ? "Goals.New" : "Goals.Edit")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: kind) { _, newValue in
                threshold = Self.defaultThreshold(kind: newValue, game: game)
                if existingGoal == nil {
                    target = newValue == .rating ? 0.0 : 10.0
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Shared.Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Goals.Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    func save() {
        var goal = existingGoal ?? AnalyticsGoal(game: game, kind: kind, target: target, deadline: deadline)
        goal.kind = kind
        goal.playStyle = playStyle
        goal.level = kind == .rating ? 0 : level
        goal.threshold = kind == .rating ? "" : threshold
        goal.target = target
        goal.deadline = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: deadline) ?? deadline
        AnalyticsGoalStore.upsert(goal)
    }
}

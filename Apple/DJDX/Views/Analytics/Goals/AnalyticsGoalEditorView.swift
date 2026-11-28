import SwiftUI

struct AnalyticsGoalEditorView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let game: Game
    let playStyle: String
    let existingGoal: AnalyticsGoal?

    @State var kind: AnalyticsGoalKind
    @State var level: Int
    @State var threshold: String
    @State var target: Double
    @State var deadline: Date

    init(goal: AnalyticsGoal?, game: Game, playStyle: String) {
        self.game = game
        self.playStyle = goal?.playStyle ?? playStyle
        self.existingGoal = goal
        let kind = goal?.kind ?? AnalyticsGoalKind.available(for: game).first ?? .clearCount
        _kind = State(initialValue: kind)
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

    var isValid: Bool {
        target > 0 && (kind == .rating || !threshold.isEmpty) && deadline > .now
    }

    var body: some View {
        NavigationStack {
            editor
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
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Compact Body

    private var editor: some View {
        let ink: Color = colorScheme == .dark ? .white : .black
        return ScrollView {
            VStack(alignment: .leading, spacing: 14.0) {
                let kinds = AnalyticsGoalKind.available(for: game)
                if kinds.count > 1 {
                    FilterChipGroup(title: Text("Goals.Kind")) {
                        ForEach(kinds, id: \.self) { option in
                            FilterTextChip(title: Text(option.titleKey(for: game)), isOn: kind == option) {
                                kind = option
                            }
                        }
                    }
                }
                if kind != .rating {
                    FilterChipGroup(title: Text("Goals.Level")) {
                        FilterTextChip(title: Text("Goals.Level.All"), isOn: level == 0) {
                            level = 0
                        }
                        ForEach(AnalyticsGoal.levelOptions(for: game), id: \.self) { option in
                            FilterChip(isOn: level == option, isDimmed: level != 0 && level != option) {
                                level = level == option ? 0 : option
                            } label: {
                                LevelNumber(level: String(option), size: 15.0)
                            }
                        }
                    }
                    FilterChipGroup(title: Text(kind == .clearCount ? "Goals.ClearType" : "Goals.Grade")) {
                        ForEach(AnalyticsGoal.thresholdOptions(kind: kind, game: game), id: \.self) { option in
                            FilterChip(isOn: threshold == option,
                                          isDimmed: !threshold.isEmpty && threshold != option) {
                                threshold = option
                            } label: {
                                thresholdChipLabel(for: option)
                            }
                        }
                    }
                } else if game == .danceDanceRevolution {
                    Text("Goals.FlareSkill.Footer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0.0) {
                    HStack(spacing: 12.0) {
                        Text("Goals.Target")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        TextField("Goals.Target", value: $target,
                                  format: kind == .rating && game == .soundVoltex
                                  ? .number.precision(.fractionLength(0...3))
                                  : .number.precision(.fractionLength(0)))
                            .font(.scoreline(size: 16.0))
                            .keyboardType(kind == .rating && game == .soundVoltex ? .decimalPad : .numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(maxWidth: 120.0)
                    }
                    .padding(.horizontal, 12.0)
                    .padding(.vertical, 10.0)
                    Divider()
                    HStack(spacing: 12.0) {
                        Text("Goals.Deadline")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        DatePicker("Goals.Deadline", selection: $deadline,
                                   in: Date.now.addingTimeInterval(86400)..., displayedComponents: .date)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 12.0)
                    .padding(.vertical, 8.0)
                }
                .background(ink.opacity(0.06), in: .rect(cornerRadius: 8.0))
                .padding(.top, 2.0)
            }
            .padding(.horizontal)
            .padding(.top, 8.0)
            .padding(.bottom, 24.0)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func thresholdChipLabel(for option: String) -> some View {
        let display = AnalyticsGoal.thresholdDisplay(option, kind: kind, game: game)
        switch (kind, game) {
        case (.clearCount, .iidxArcade), (.clearCount, .iidxInfinitas):
            IIDXMetallicText.clearType(option)
                .font(.system(size: 12.0))
        case (.gradeCount, .iidxArcade), (.gradeCount, .iidxInfinitas):
            IIDXMetallicText.djLevel(option)
                .font(.system(size: 14.0))
        case (.clearCount, .soundVoltex):
            Text(verbatim: SDVXClearType(rawValue: option)?.abbreviation ?? display)
                .font(.system(size: 12.0, weight: .bold))
                .fontWidth(.expanded)
                .foregroundStyle(SDVXClearType(rawValue: option)?.color ?? .primary)
        case (.gradeCount, .soundVoltex):
            Text(verbatim: display)
                .font(.system(size: 13.0, weight: .black))
                .fontWidth(.expanded)
                .sdvxGradeText()
        case (.clearCount, .danceDanceRevolution):
            Text(verbatim: display)
                .font(.system(size: 12.0, weight: .heavy))
                .fontWidth(.expanded)
                .foregroundStyle(DDRSongRecord.clearColor(for: option))
        case (.gradeCount, .danceDanceRevolution):
            Text(verbatim: display)
                .font(.system(size: 13.0, weight: .black))
                .fontWidth(.expanded)
                .foregroundStyle(DDRSongRecord.rankColor(forStem: option))
        default:
            Text(verbatim: display)
                .font(.system(size: 12.0, weight: .bold))
        }
    }

    // MARK: - Standard Form Body

    func save() {
        var goal = existingGoal ?? AnalyticsGoal(game: game, kind: kind, target: target, deadline: deadline)
        let newLevel = kind == .rating ? 0 : level
        let newThreshold = kind == .rating ? "" : threshold
        if goal.kind != kind || goal.playStyle != playStyle
            || goal.level != newLevel || goal.threshold != newThreshold {
            goal.startValue = nil
        }
        goal.kind = kind
        goal.playStyle = playStyle
        goal.level = newLevel
        goal.threshold = newThreshold
        goal.target = target
        goal.deadline = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: deadline) ?? deadline
        AnalyticsGoalStore.upsert(goal)
    }
}

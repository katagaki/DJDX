import Charts
import SwiftUI

struct AnalyticsGoalDetailView: View {

    @EnvironmentObject var navigationManager: NavigationManager

    let goalID: UUID

    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion

    @State var progress: AnalyticsGoalProgress?
    @State var isEditing: Bool = false
    @State var isConfirmingDelete: Bool = false

    var body: some View {
        List {
            if let progress {
                Section {
                    header(progress)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8.0, leading: 16.0, bottom: 0.0, trailing: 16.0))
                    chart(progress)
                        .frame(height: 220.0)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8.0, leading: 16.0, bottom: 8.0, trailing: 16.0))
                }
                Section {
                    row("Goals.Start", progress.goal.formatted(progress.baseline))
                    row("Goals.Expected", progress.goal.formatted(progress.expected))
                    row("Goals.Remaining", progress.goal.formatted(progress.remaining))
                }
                Section {
                    row("Goals.StartDate", progress.goal.startDate.formatted(date: .long, time: .omitted),
                        isNumeric: false)
                    row("Goals.Deadline", progress.goal.deadline.formatted(date: .long, time: .omitted),
                        isNumeric: false)
                    HStack {
                        Text("Goals.TimeLeft")
                        Spacer()
                        Text("Goals.DaysLeft.\(progress.daysLeft)")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Goals.Delete", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Goals.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Shared.Edit", systemImage: "pencil") {
                    isEditing = true
                }
                .disabled(progress == nil)
            }
        }
        .sheet(isPresented: $isEditing) {
            if let goal = progress?.goal {
                AnalyticsGoalEditorView(goal: goal, game: goal.game, playStyle: goal.playStyle)
            }
        }
        .alert("Goals.Delete.Confirm", isPresented: $isConfirmingDelete) {
            Button("Goals.Delete", role: .destructive) {
                AnalyticsGoalStore.delete(goalID)
                if !navigationManager.path.isEmpty {
                    navigationManager.path.removeLast()
                }
            }
            Button("Shared.Cancel", role: .cancel) { }
        }
        .task {
            await reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .analyticsGoalsDidChange)) { _ in
            Task { await reload() }
        }
    }

    func row(_ title: LocalizedStringKey, _ value: String, isNumeric: Bool = true) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: value)
                .fontWeight(isNumeric ? .semibold : .regular)
                .fontWidth(isNumeric ? .expanded : .standard)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    func header(_ progress: AnalyticsGoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            AnalyticsGoalTitle(goal: progress.goal)
                .font(.subheadline)
            HStack(alignment: .center, spacing: 8.0) {
                HStack(alignment: .firstTextBaseline, spacing: 4.0) {
                    Text(verbatim: progress.goal.formatted(progress.current))
                        .goalNumberFont(size: 34.0)
                    Text(verbatim: "/ \(progress.goal.formatted(progress.goal.target))")
                        .font(.scoreline(.title3, weight: .bold))
                        .fontWidth(.standard)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0.0)
                AnalyticsGoalStatusBadge(status: progress.status, isLarge: true)
            }
        }
    }

    func chart(_ progress: AnalyticsGoalProgress) -> some View {
        let goal = progress.goal
        let progressLabel = String(localized: "Goals.Chart.Progress")
        let paceLabel = String(localized: "Goals.Chart.Pace")
        let points = progress.history.filter { $0.date >= goal.startDate }
        let startPoint = AnalyticsGoalPoint(date: goal.startDate, value: progress.baseline)
        return Chart {
            ForEach([startPoint] + points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value),
                         series: .value("Series", progressLabel))
                .foregroundStyle(by: .value("Series", progressLabel))
                .interpolationMethod(.monotone)
                PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .foregroundStyle(by: .value("Series", progressLabel))
                    .symbolSize(24.0)
            }
            LineMark(x: .value("Date", goal.startDate), y: .value("Value", progress.baseline),
                     series: .value("Series", paceLabel))
            .foregroundStyle(by: .value("Series", paceLabel))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4.0, 4.0]))
            LineMark(x: .value("Date", goal.deadline), y: .value("Value", goal.target),
                     series: .value("Series", paceLabel))
            .foregroundStyle(by: .value("Series", paceLabel))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4.0, 4.0]))
            RuleMark(y: .value("Target", goal.target))
                .foregroundStyle(.secondary.opacity(0.5))
            RuleMark(x: .value("Today", progress.now))
                .foregroundStyle(.secondary.opacity(0.3))
        }
        .chartForegroundStyleScale([progressLabel: progress.status.color, paceLabel: Color.secondary])
        .chartXScale(domain: goal.startDate...max(goal.deadline, goal.startDate.addingTimeInterval(86400)))
        .chartLegend(position: .bottom)
    }

    func reload() async {
        guard let goal = AnalyticsGoalStore.load().first(where: { $0.id == goalID }) else {
            progress = nil
            return
        }
        let computed = await AnalyticsGoalEvaluator.progress(
            for: [goal], iidxVersion: iidxVersion, sdvxVersion: sdvxVersion, ddrVersion: ddrVersion
        )
        withAnimation(.smooth.speed(2.0)) {
            progress = computed.first
        }
    }
}

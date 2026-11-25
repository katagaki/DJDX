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
                    chart(progress)
                        .frame(height: 220.0)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8.0, leading: 16.0, bottom: 8.0, trailing: 16.0))
                }
                Section {
                    HStack {
                        Text("Goals.Status")
                        Spacer()
                        AnalyticsGoalStatusBadge(status: progress.status)
                    }
                    row("Goals.Current", progress.goal.formatted(progress.current))
                    row("Goals.Target", progress.goal.formatted(progress.goal.target))
                    row("Goals.Start", progress.goal.formatted(progress.baseline))
                    row("Goals.Expected", progress.goal.formatted(progress.expected))
                    row("Goals.Remaining", progress.goal.formatted(progress.remaining))
                }
                Section {
                    row("Goals.StartDate", progress.goal.startDate.formatted(date: .long, time: .omitted))
                    row("Goals.Deadline", progress.goal.deadline.formatted(date: .long, time: .omitted))
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
        .navigationTitle(Text(verbatim: progress?.goal.title ?? ""))
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

    func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
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

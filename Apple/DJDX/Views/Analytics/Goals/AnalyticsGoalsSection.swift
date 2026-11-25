import SwiftUI

struct AnalyticsGoalsSection: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let game: Game
    let playStyle: String

    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: false, "Analytics.Goals.Collapsed") var isCollapsed: Bool

    @State var progresses: [AnalyticsGoalProgress] = []
    @State var isAddingGoal: Bool = false

    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12.0), count: horizontalSizeClass == .regular ? 2 : 1)
    }

    var body: some View {
        if !AnalyticsGoalKind.available(for: game).isEmpty {
            VStack(spacing: 12.0) {
                HStack(spacing: 0.0) {
                    AnalyticsSectionHeader(title: "Goals.Title", isCollapsible: true, isExpanded: !isCollapsed) {
                        withAnimation(.smooth.speed(2.0)) { isCollapsed.toggle() }
                    }
                    Button("Goals.Add", systemImage: "plus") {
                        isAddingGoal = true
                    }
                    .labelStyle(.iconOnly)
                    .font(.body.bold())
                    .padding(.trailing)
                }
                if !isCollapsed {
                    LazyVGrid(columns: columns, spacing: 12.0) {
                        if progresses.isEmpty {
                            emptyCard
                        }
                        ForEach(progresses) { progress in
                            Button {
                                navigationManager.push(AnalyticsGoalPath.detail(id: progress.goal.id))
                            } label: {
                                AnalyticsGoalCard(progress: progress)
                            }
                            .buttonStyle(AnalyticsCardButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .task(id: reloadKey) {
                await reload()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
                Task { await reload() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .analyticsGoalsDidChange)) { _ in
                Task { await reload() }
            }
            .sheet(isPresented: $isAddingGoal) {
                AnalyticsGoalEditorView(goal: nil, game: game, playStyle: playStyle)
            }
        }
    }

    var reloadKey: String {
        "\(game.rawValue)-\(iidxVersion.rawValue)-\(sdvxVersion.rawValue)-\(ddrVersion.rawValue)"
    }

    var emptyCard: some View {
        Button {
            isAddingGoal = true
        } label: {
            VStack(spacing: 6.0) {
                Image(systemName: "flag.checkered")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Goals.Empty.Title")
                    .font(.subheadline.bold())
                Text("Goals.Empty.Message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16.0)
            .frame(maxWidth: .infinity)
            .cardBackground(cornerRadius: AnalyticsGoalCard.cornerRadius)
        }
        .buttonStyle(AnalyticsCardButtonStyle())
    }

    func reload() async {
        let goals = AnalyticsGoalStore.load().filter { $0.game == game }
        let computed = await AnalyticsGoalEvaluator.progress(
            for: goals, iidxVersion: iidxVersion, sdvxVersion: sdvxVersion, ddrVersion: ddrVersion
        )
        withAnimation(.smooth.speed(2.0)) {
            progresses = computed.sorted { $0.goal.deadline < $1.goal.deadline }
        }
    }
}

struct AnalyticsGoalCard: View {

    static var cornerRadius: CGFloat {
        if #available(iOS 26.0, *) { 20.0 } else { 12.0 }
    }

    let progress: AnalyticsGoalProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack(spacing: 6.0) {
                AnalyticsGoalTitle(goal: progress.goal)
                    .font(.caption)
                Spacer(minLength: 4.0)
                AnalyticsGoalStatusBadge(status: progress.status)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4.0) {
                Text(verbatim: progress.goal.formatted(progress.current))
                    .goalNumberFont(size: 20.0)
                Text(verbatim: "/ \(progress.goal.formatted(progress.goal.target))")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .fontWidth(.expanded)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Goals.DaysLeft.\(progress.daysLeft)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            AnalyticsGoalProgressBar(progress: progress.progressFraction,
                                     pace: progress.timeFraction,
                                     color: progress.status.color)
            HStack {
                Text("Goals.Pace.\(progress.goal.formatted(progress.expected))")
                Spacer()
                Text("Goals.Due.\(progress.goal.deadline.formatted(date: .abbreviated, time: .omitted))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: Self.cornerRadius)
    }
}

struct AnalyticsGoalStatusBadge: View {
    let status: AnalyticsGoalStatus

    var body: some View {
        Label(status.titleKey, systemImage: status.systemImage)
            .font(.caption2.weight(.heavy))
            .fontWidth(.expanded)
            .foregroundStyle(status.color)
            .padding(.horizontal, 8.0)
            .padding(.vertical, 3.0)
            .background(status.color.opacity(0.15), in: .capsule)
            .lineLimit(1)
    }
}

struct AnalyticsGoalProgressBar: View {
    let progress: Double
    let pace: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.2))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(proxy.size.width * progress, progress > 0 ? 8.0 : 0.0))
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2.0, height: proxy.size.height + 6.0)
                    .offset(x: min(max(proxy.size.width * pace - 1.0, 0.0), proxy.size.width - 2.0))
            }
        }
        .frame(height: 8.0)
        .padding(.vertical, 3.0)
    }
}

import SwiftUI

struct AnalyticsGoalsSection: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let game: Game
    let playStyle: String

    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: false, "Analytics.Goals.Collapsed") var isCollapsedStored: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.goalsKey) var isGoalsVisible: Bool

    @State var isCollapsed: Bool = UserDefaults.standard.bool(forKey: "Analytics.Goals.Collapsed")

    @State var progresses: [AnalyticsGoalProgress] = []
    @State var isAddingGoal: Bool = false

    var columnCount: Int {
        horizontalSizeClass == .regular ? 2 : 1
    }

    var body: some View {
        if isGoalsVisible, !AnalyticsGoalKind.available(for: game).isEmpty {
            VStack(spacing: DesignMetrics.gap) {
                AnalyticsSectionHeader(title: "Goals.Title", isCollapsible: true, isExpanded: !isCollapsed) {
                    withAnimation(.smooth.speed(2.0)) { isCollapsed.toggle() }
                    isCollapsedStored = isCollapsed
                } accessory: {
                    Button("Goals.Add", systemImage: "plus") {
                        isAddingGoal = true
                    }
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.bold))
                }
                if !isCollapsed {
                    Group {
                        if progresses.isEmpty {
                            emptyCard
                        } else {
                            AnalyticsCardGrid(items: progresses, columns: columnCount, spacing: DesignMetrics.gap) { progress in
                                Button {
                                    navigationManager.push(AnalyticsGoalPath.detail(id: progress.goal.id))
                                } label: {
                                    AnalyticsGoalCard(progress: progress)
                                }
                                .buttonStyle(AnalyticsCardButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .padding(.top, DesignMetrics.sectionGap)
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
        "\(game.rawValue)-\(playStyle)-\(iidxVersion.rawValue)-\(sdvxVersion.rawValue)-\(ddrVersion.rawValue)"
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
            .cardBackground()
        }
        .buttonStyle(AnalyticsCardButtonStyle())
    }

    func reload() async {
        let goals = AnalyticsGoalStore.load().filter { goal in
            guard goal.game == game else { return false }
            if playStyle.isEmpty { return true }
            if goal.playStyle.isEmpty {
                return playStyle == IIDXPlayType.single.rawValue || playStyle == DDRPlayStyle.single.rawValue
            }
            return goal.playStyle == playStyle
        }
        let computed = await AnalyticsGoalEvaluator.progress(
            for: goals, iidxVersion: iidxVersion, sdvxVersion: sdvxVersion, ddrVersion: ddrVersion
        )
        withAnimation(.smooth.speed(2.0)) {
            progresses = computed.sorted { $0.goal.deadline < $1.goal.deadline }
        }
    }
}

struct AnalyticsGoalCard: View {
    let progress: AnalyticsGoalProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6.0) {
            HStack(alignment: .center, spacing: 6.0) {
                AnalyticsGoalTitle(goal: progress.goal)
                    .font(.caption)
                Spacer(minLength: 4.0)
                AnalyticsGoalStatusBadge(status: progress.status)
            }
            HStack(alignment: .center, spacing: 8.0) {
                HStack(alignment: .firstTextBaseline, spacing: 3.0) {
                    Text(verbatim: progress.goal.formatted(progress.current))
                        .goalNumberFont(size: 13.0)
                    Text(verbatim: "/ \(progress.goal.formatted(progress.goal.target))")
                        .goalNumberFont(size: 13.0)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .fixedSize()
                AnalyticsGoalProgressBar(progress: progress.progressFraction,
                                         pace: progress.timeFraction,
                                         color: progress.status.color,
                                         height: 11.0)
                Text("Goals.Days.\(progress.daysLeft)")
                    .goalNumberFont(size: 13.0)
                    .foregroundStyle(.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 10.0)
        .padding(.vertical, 8.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .environment(\.cardRailColor, progress.status == .notStarted ? nil : progress.status.color)
    }
}

struct AnalyticsGoalStatusBadge: View {
    let status: AnalyticsGoalStatus
    var isLarge: Bool = false

    private var fill: LinearGradient {
        if status == .notStarted {
            return LinearGradient(colors: [Color(hex: 0x2A2D33), Color(hex: 0x111215)],
                                  startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(
            colors: [
                status.color.mix(with: Color(hex: 0x2A2D33), by: 0.72),
                status.color.mix(with: Color(hex: 0x111215), by: 0.82)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var foreground: Color {
        status == .notStarted
            ? .white.opacity(0.75)
            : status.color.mix(with: .white, by: 0.35)
    }

    private var border: Color {
        status == .notStarted ? .white.opacity(0.25) : status.color.opacity(0.6)
    }

    var body: some View {
        let radius: CGFloat = isLarge ? 6.0 : 4.0
        HStack(spacing: isLarge ? 5.0 : 3.5) {
            Image(systemName: status.systemImage)
            Text(status.titleKey)
                .fontWidth(.expanded)
        }
        .font(isLarge ? .subheadline.weight(.heavy) : .caption2.weight(.heavy))
        .foregroundStyle(foreground)
        .padding(.horizontal, isLarge ? 10.0 : 6.0)
        .frame(height: isLarge ? 32.0 : 20.0)
        .background(fill)
        .clipShape(.rect(cornerRadius: radius))
        .overlay {
            RoundedRectangle(cornerRadius: radius).strokeBorder(border, lineWidth: 1.0)
        }
        .lineLimit(1)
        .fixedSize()
    }
}

struct AnalyticsGoalProgressBar: View {
    let progress: Double
    let pace: Double
    let color: Color
    var height: CGFloat = 8.0

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.secondary.opacity(0.2))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(color.gradient)
                        .frame(width: max(proxy.size.width * progress, progress > 0 ? 8.0 : 0.0))
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2.0, height: proxy.size.height + 6.0)
                        .offset(x: min(max(proxy.size.width * pace - 1.0, 0.0), proxy.size.width - 2.0))
                }
        }
        .frame(height: height)
        .padding(.vertical, 3.0)
    }
}

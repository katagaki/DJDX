import SwiftUI

struct SessionsView: View {
    var store: IIDXSessionStore
    var analyticsModel: AnalyticsModel
    var analyticsNamespace: Namespace.ID
    var towerNamespace: Namespace.ID

    @State private var isPresentingActive: Bool = false
    @State private var isPresentingExternalDataSources: Bool = false
    @State private var isHistoryExpanded: Bool = true
    @State private var isScoreDataExpanded: Bool = true
    @State private var latestPlays: [IIDXCapturedPlay] = []
    @State private var playHistories: [String: [IIDXCapturedPlay]] = [:]
    @State private var songCompactTitles: [String: IIDXSong] = [:]
    @AppStorage(wrappedValue: false, "ExternalData.BemaniWiki2nd.Enabled") private var isBemaniWikiEnabled: Bool
    @AppStorage(wrappedValue: true, "More.General.ShowAnalytics") private var showAnalytics: Bool

    private let reader = IIDXReader()

    private var pastSessions: [IIDXPlaySession] {
        store.sessions.filter { !$0.isActive }.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if !isBemaniWikiEnabled || store.activeSession != nil {
                    VStack(spacing: 12.0) {
                        if !isBemaniWikiEnabled {
                            sessionsCard { bemaniWikiWarning }
                        }
                        if let active = store.activeSession {
                            Button {
                                isPresentingActive = true
                            } label: {
                                sessionsCard { resumeCard(active) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8.0)
                }
                historySection
                    .padding(.top, 20.0)
                if showAnalytics {
                    AnalyticsView(model: analyticsModel,
                                  isEditing: .constant(false),
                                  analyticsNamespace: analyticsNamespace,
                                  towerNamespace: towerNamespace)
                }
                scoreDataSection
                    .padding(.top, 20.0)
            }
            .padding(.bottom, 8.0)
        }
        .background {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onAppear {
            store.bootstrap()
            if store.activeSession != nil { isPresentingActive = true }
        }
        .task {
            songCompactTitles = await reader.songCompactTitles()
            reloadScores()
        }
        .onChange(of: store.activeSession?.id) { _, newValue in
            isPresentingActive = newValue != nil
        }
        .onChange(of: store.pendingCaptureRequest) { _, pending in
            if pending, store.activeSession != nil { isPresentingActive = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playSessionDidChange)
            .receive(on: RunLoop.main)) { _ in
            store.loadSessions()
            reloadScores()
        }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .receive(on: RunLoop.main)) { _ in
            reloadScores()
        }
        .fullScreenCover(isPresented: $isPresentingActive) {
            ActiveSessionView(store: store)
        }
        .sheet(isPresented: $isPresentingExternalDataSources) {
            NavigationStack {
                MoreExternalDataSources()
            }
        }
    }

    private var bemaniWikiWarning: some View {
        SessionsNoticeRow(
            systemImage: "exclamationmark.triangle.fill",
            color: .orange,
            title: "Sessions.DataSource.Warning.Title",
            message: "Sessions.DataSource.Warning.Message"
        ) {
            Button("Sessions.DataSource.Warning.Action") {
                isPresentingExternalDataSources = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .buttonStyle(.plain)
        }
    }

    private var historySection: some View {
        VStack(spacing: 12.0) {
            AnalyticsSectionHeader(
                title: "Sessions.History.Title",
                isCollapsible: true,
                isExpanded: isHistoryExpanded
            ) {
                withAnimation(.smooth.speed(2.0)) { isHistoryExpanded.toggle() }
            }
            if isHistoryExpanded {
                if pastSessions.isEmpty {
                    Text("Sessions.History.Empty.Message")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                } else {
                    SessionCardsRow(store: store, sessions: pastSessions)
                }
            }
        }
    }

    private var scoreDataSection: some View {
        SessionScoreDataSection(
            store: store,
            latestPlays: latestPlays,
            playHistories: playHistories,
            songCompactTitles: songCompactTitles,
            isExpanded: $isScoreDataExpanded
        )
    }

    private func sessionsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let cornerRadius: CGFloat
        if #available(iOS 26.0, *) {
            cornerRadius = 20.0
        } else {
            cornerRadius = 12.0
        }
        return content()
            .padding(12.0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground(cornerRadius: cornerRadius)
    }

    private func reloadScores() {
        var allPlays: [IIDXCapturedPlay] = []
        for session in store.sessions {
            allPlays.append(contentsOf: store.plays(for: session))
        }
        allPlays = allPlays.filter { play in
            guard play.state == .done || play.state == .needsReview else { return false }
            guard play.difficulty > 0 else { return false }
            guard let title = play.songTitle, !title.isEmpty else { return false }
            return true
        }
        var histories: [String: [IIDXCapturedPlay]] = [:]
        for play in allPlays {
            histories[play.chartKey(), default: []].append(play)
        }
        for key in histories.keys {
            histories[key]?.sort { $0.captureDate > $1.captureDate }
        }
        playHistories = histories
        latestPlays = histories.values.compactMap(\.first).sorted { $0.captureDate > $1.captureDate }
    }

    private func resumeCard(_ session: IIDXPlaySession) -> some View {
        HStack {
            Image(systemName: "record.circle")
                .foregroundStyle(.red)
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 2.0) {
                Text("Sessions.InProgress")
                    .font(.headline)
                Text(session.startDate, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
    }
}

struct SessionScoreDataSection: View {
    var store: IIDXSessionStore
    var latestPlays: [IIDXCapturedPlay]
    var playHistories: [String: [IIDXCapturedPlay]]
    var songCompactTitles: [String: IIDXSong]
    @Binding var isExpanded: Bool

    @Namespace private var scoresNamespace

    var body: some View {
        VStack(spacing: 0.0) {
            AnalyticsSectionHeader(
                title: "Analytics.Section.ScoreData",
                isCollapsible: true,
                isExpanded: isExpanded
            ) {
                withAnimation(.smooth.speed(2.0)) { isExpanded.toggle() }
            }
            .padding(.bottom, 12.0)
            if isExpanded {
                if latestPlays.isEmpty {
                    Text("Sessions.Empty.Title")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24.0)
                } else {
                    Divider()
                    ForEach(latestPlays) { play in
                        NavigationLink {
                            scoreDestination(for: play)
                        } label: {
                            IIDXScoreRow(
                                namespace: scoresNamespace,
                                songRecord: play.asSongRecord(),
                                level: play.level == .unknown ? .another : play.level,
                                score: play.levelScore(),
                                scoreRate: scoreRate(for: play)
                            )
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scoreDestination(for play: IIDXCapturedPlay) -> some View {
        let history = Array(playHistories[play.chartKey()]?.dropFirst() ?? [])
        if play.hasConfidentResult {
            CapturedPlayScoreView(store: store, play: play, history: history)
        } else {
            CapturedPlayDetailView(store: store, play: play)
        }
    }

    private func scoreRate(for play: IIDXCapturedPlay) -> Float? {
        guard let title = play.songTitle,
              let noteCount = songCompactTitles[title.compact]?.spNoteCount?.noteCount(for: play.level),
              noteCount > 0 else { return nil }
        return Float(play.exScore) / Float(noteCount * 2)
    }
}

struct SessionsNoticeRow<Accessory: View>: View {
    var systemImage: String
    var color: Color
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    @ViewBuilder var accessory: () -> Accessory

    init(systemImage: String,
         color: Color,
         title: LocalizedStringKey,
         message: LocalizedStringKey,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.systemImage = systemImage
        self.color = color
        self.title = title
        self.message = message
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12.0) {
            Image(systemName: systemImage)
                .font(.system(size: 18.0, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36.0, height: 36.0)
                .background(color, in: RoundedRectangle(cornerRadius: 9.0, style: .continuous))
            VStack(alignment: .leading, spacing: 3.0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                accessory()
            }
            Spacer(minLength: 0.0)
        }
        .padding(.vertical, 4.0)
    }
}

struct SessionsHelpMenu: View {
    @AppStorage(wrappedValue: false, IIDXSessionWorkoutBridge.healthKitEnabledKey) private var healthKitEnabled: Bool

    var body: some View {
        Menu {
            Text("Sessions.Welcome.Message")
            Divider()
            Toggle(isOn: $healthKitEnabled) {
                Label("Sessions.HealthKit.Toggle", systemImage: "heart.fill")
            }
        } label: {
            Label("Sessions.Help", systemImage: "questionmark.circle")
        }
        .menuOrder(.fixed)
        .onChange(of: healthKitEnabled) { _, enabled in
            if enabled {
                Task { _ = await IIDXSessionWorkoutBridge.shared.requestAuthorization() }
            }
            IIDXSessionWorkoutBridge.shared.syncProfileToWatch()
        }
    }
}

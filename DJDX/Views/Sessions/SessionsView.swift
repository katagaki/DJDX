import SwiftUI

struct SessionsView: View {
    var store: IIDXSessionStore
    var analyticsModel: AnalyticsModel
    var analyticsNamespace: Namespace.ID
    var towerNamespace: Namespace.ID

    @State private var isPresentingActive: Bool = false
    @State private var isPresentingExternalDataSources: Bool = false
    @State private var latestPlays: [IIDXCapturedPlay] = []
    @State private var playHistories: [String: [IIDXCapturedPlay]] = [:]
    @State private var songCompactTitles: [String: IIDXSong] = [:]
    @AppStorage(wrappedValue: false, IIDXSessionWorkoutBridge.healthKitEnabledKey) private var healthKitEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.BemaniWiki2nd.Enabled") private var isBemaniWikiEnabled: Bool
    @AppStorage(wrappedValue: true, "More.General.ShowAnalytics") private var showAnalytics: Bool

    @Namespace private var scoresNamespace

    private let reader = IIDXReader()

    private var pastSessions: [IIDXPlaySession] {
        store.sessions.filter { !$0.isActive }.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        List {
            Section {
                betaNotice
            }
            if !isBemaniWikiEnabled {
                Section {
                    bemaniWikiWarning
                }
            }
            Section {
                Toggle(isOn: $healthKitEnabled) {
                    HStack(alignment: .top, spacing: 12.0) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18.0, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36.0, height: 36.0)
                            .background(.pink, in: RoundedRectangle(cornerRadius: 9.0, style: .continuous))
                        VStack(alignment: .leading, spacing: 3.0) {
                            Text("Sessions.HealthKit.Toggle")
                                .font(.subheadline.weight(.semibold))
                            Text("Sessions.HealthKit.Footer")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let active = store.activeSession {
                Section {
                    Button {
                        isPresentingActive = true
                    } label: {
                        resumeCard(active)
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("Sessions.History.Title") {
                if pastSessions.isEmpty {
                    Text("Sessions.History.Empty.Message")
                        .foregroundStyle(.secondary)
                } else {
                    sessionCards
                }
            }
            if showAnalytics {
                Section {
                    AnalyticsView(model: analyticsModel,
                                  isEditing: .constant(false),
                                  analyticsNamespace: analyticsNamespace,
                                  towerNamespace: towerNamespace)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            Section("Analytics.Section.ScoreData") {
                if latestPlays.isEmpty {
                    Text("Sessions.Empty.Title")
                        .foregroundStyle(.secondary)
                } else {
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
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, 8.0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onChange(of: healthKitEnabled) { _, enabled in
            if enabled {
                Task { _ = await IIDXSessionWorkoutBridge.shared.requestAuthorization() }
            }
            IIDXSessionWorkoutBridge.shared.syncProfileToWatch()
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

    private var betaNotice: some View {
        HStack(alignment: .top, spacing: 12.0) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 18.0, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36.0, height: 36.0)
                .background(.accent, in: RoundedRectangle(cornerRadius: 9.0, style: .continuous))
            VStack(alignment: .leading, spacing: 3.0) {
                Text("Sessions.Beta.Title")
                    .font(.subheadline.weight(.semibold))
                Text("Sessions.Welcome.Message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0.0)
        }
        .padding(.vertical, 4.0)
    }

    private var bemaniWikiWarning: some View {
        HStack(alignment: .top, spacing: 12.0) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18.0, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36.0, height: 36.0)
                .background(.orange, in: RoundedRectangle(cornerRadius: 9.0, style: .continuous))
            VStack(alignment: .leading, spacing: 3.0) {
                Text("Sessions.DataSource.Warning.Title")
                    .font(.subheadline.weight(.semibold))
                Text("Sessions.DataSource.Warning.Message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Sessions.DataSource.Warning.Action") {
                    isPresentingExternalDataSources = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0.0)
        }
        .padding(.vertical, 4.0)
    }

    private var sessionCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12.0) {
                ForEach(pastSessions) { session in
                    NavigationLink {
                        SessionDetailView(store: store, session: session)
                    } label: {
                        sessionCard(session)
                    }
                    .buttonStyle(AnalyticsCardButtonStyle())
                    .contextMenu {
                        Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                            store.deleteSession(session)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func sessionCard(_ session: IIDXPlaySession) -> some View {
        let cornerRadius: CGFloat
        if #available(iOS 26.0, *) {
            cornerRadius = 20.0
        } else {
            cornerRadius = 12.0
        }
        return VStack(alignment: .leading, spacing: 4.0) {
            Text(verbatim: durationText(for: session))
                .font(.system(size: 20.0, weight: .black))
                .fontWidth(.expanded)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0.0)
            Text(session.startDate, format: .dateTime.year().month().day())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(12.0)
        .frame(width: 148.0, height: 88.0, alignment: .leading)
        .cardBackground(cornerRadius: cornerRadius)
    }

    private func durationText(for session: IIDXPlaySession) -> String {
        let minutes = Int(session.duration / 60.0)
        return String(localized: "Sessions.Duration.\(minutes)")
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

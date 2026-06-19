import SwiftUI

struct SessionsView: View {
    var store: IIDXSessionStore

    @State private var isPresentingActive: Bool = false
    @State private var isPresentingExternalDataSources: Bool = false
    @AppStorage(wrappedValue: false, IIDXSessionWorkoutBridge.healthKitEnabledKey) private var healthKitEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.BemaniWiki2nd.Enabled") private var isBemaniWikiEnabled: Bool

    private var pastSessions: [IIDXPlaySession] {
        store.sessions.filter { !$0.isActive }
    }

    var body: some View {
        List {
            Section {
                betaNotice
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10.0, style: .continuous)
                            .fill(.accent.opacity(0.12))
                    )
            } footer: {
                Text("Sessions.Welcome.Message")
            }
            if !isBemaniWikiEnabled {
                Section {
                    bemaniWikiWarning
                }
            }
            Section {
                Toggle(isOn: $healthKitEnabled) {
                    Label("Sessions.HealthKit.Toggle", systemImage: "heart.text.square")
                }
            } footer: {
                Text("Sessions.HealthKit.Footer")
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
                }
                ForEach(pastSessions) { session in
                    NavigationLink {
                        SessionDetailView(store: store, session: session)
                    } label: {
                        SessionSummaryRow(store: store, session: session)
                    }
                }
                .onDelete { offsets in
                    for offset in offsets { store.deleteSession(pastSessions[offset]) }
                }
            }
        }
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
        }
        .onAppear {
            store.bootstrap()
            if store.activeSession != nil { isPresentingActive = true }
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
        HStack(spacing: 12.0) {
            Image(systemName: "figure.walk")
                .font(.system(size: 18.0, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36.0, height: 36.0)
                .background(.accent, in: RoundedRectangle(cornerRadius: 9.0, style: .continuous))
            VStack(alignment: .leading, spacing: 3.0) {
                HStack(spacing: 6.0) {
                    Text("Sessions.Beta.Title")
                        .font(.subheadline.weight(.semibold))
                    Text("Sessions.Beta.Badge")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.accent)
                        .padding(.horizontal, 6.0)
                        .padding(.vertical, 2.0)
                        .background(.accent.opacity(0.18), in: Capsule())
                }
                Text("Sessions.Beta.Message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0.0)
        }
        .padding(.vertical, 4.0)
    }

    private var bemaniWikiWarning: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack(spacing: 8.0) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Sessions.DataSource.Warning.Title")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            Text("Sessions.DataSource.Warning.Message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Sessions.DataSource.Warning.Action") {
                isPresentingExternalDataSources = true
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4.0)
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

struct SessionSummaryRow: View {
    var store: IIDXSessionStore
    var session: IIDXPlaySession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2.0) {
                Text(session.startDate, format: .dateTime.year().month().day())
                    .font(.subheadline.weight(.semibold))
                Text(durationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Sessions.PlayCount.\(store.plays(for: session).count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var durationText: String {
        let minutes = Int(session.duration / 60.0)
        return String(localized: "Sessions.Duration.\(minutes)")
    }
}

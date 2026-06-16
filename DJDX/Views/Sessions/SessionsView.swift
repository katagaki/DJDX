import SwiftUI

struct SessionsView: View {
    var store: SessionStore

    @State private var isPresentingActive: Bool = false
    @AppStorage(wrappedValue: false, SessionWorkoutBridge.healthKitEnabledKey) private var healthKitEnabled: Bool

    private var pastSessions: [PlaySession] {
        store.sessions.filter { !$0.isActive }
    }

    var body: some View {
        List {
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
        .onChange(of: healthKitEnabled) { _, enabled in
            if enabled {
                Task { _ = await SessionWorkoutBridge.shared.requestAuthorization() }
            }
        }
        .onAppear {
            store.bootstrap()
            if store.activeSession != nil { isPresentingActive = true }
        }
        .onChange(of: store.activeSession?.id) { _, newValue in
            isPresentingActive = newValue != nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .playSessionDidChange)
            .receive(on: RunLoop.main)) { _ in
            store.loadSessions()
        }
        .fullScreenCover(isPresented: $isPresentingActive) {
            ActiveSessionView(store: store)
        }
    }

    private func resumeCard(_ session: PlaySession) -> some View {
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
    var store: SessionStore
    var session: PlaySession

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

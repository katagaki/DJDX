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

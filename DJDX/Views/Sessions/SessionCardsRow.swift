import SwiftUI

struct SessionCardsRow: View {
    var store: IIDXSessionStore
    var sessions: [IIDXPlaySession]
    var onResume: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12.0) {
                if let active = store.activeSession {
                    Button(action: onResume) {
                        activeSessionCard(active)
                    }
                    .buttonStyle(AnalyticsCardButtonStyle())
                }
                ForEach(sessions) { session in
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
    }

    private var cornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            20.0
        } else {
            12.0
        }
    }

    private func activeSessionCard(_ session: IIDXPlaySession) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Text("Sessions.InProgress")
                .font(.system(size: 20.0, weight: .black))
                .fontWidth(.expanded)
                .foregroundStyle(.red)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0.0)
            Text(session.startDate, format: .dateTime.hour().minute())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(12.0)
        .frame(width: 148.0, height: 108.0, alignment: .leading)
        .cardBackground(cornerRadius: cornerRadius)
    }

    private func sessionCard(_ session: IIDXPlaySession) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Text(verbatim: durationText(for: session))
                .font(.system(size: 20.0, weight: .black))
                .fontWidth(.expanded)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
            Spacer(minLength: 0.0)
            Text(session.startDate, format: .dateTime.year().month().day())
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(12.0)
        .frame(width: 148.0, height: 108.0, alignment: .leading)
        .cardBackground(cornerRadius: cornerRadius)
    }

    private func durationText(for session: IIDXPlaySession) -> String {
        let totalMinutes = Int(session.duration / 60.0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(localized: "Sessions.Duration.Hours.\(hours)") + "\n" +
                String(localized: "Sessions.Duration.\(minutes)")
        }
        return String(localized: "Sessions.Duration.\(minutes)")
    }
}

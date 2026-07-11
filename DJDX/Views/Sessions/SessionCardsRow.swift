import SwiftUI

struct SessionCardsRow: View {
    var store: IIDXSessionStore
    var sessions: [IIDXPlaySession]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12.0) {
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

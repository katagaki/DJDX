import SwiftUI

extension SessionsView {

    @ViewBuilder var sortControl: some View {
        IIDXScoreSortMenu(
            sortMode: $sortMode.animation(.smooth.speed(2.0)),
            sortOrder: $sortOrder.animation(.smooth.speed(2.0))
        )
    }

    @ViewBuilder var filterControl: some View {
        ScoreFilterButton(
            isShowingFilterSheet: $isShowingFilterSheet,
            filterNamespace: sessionsNamespace
        )
    }

    var bemaniWikiWarning: some View {
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

    var historySection: some View {
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

    var scoreDataSection: some View {
        SessionScoreDataSection(
            store: store,
            plays: displayedPlays,
            playHistories: playHistories,
            songCompactTitles: songCompactTitles,
            isSearching: isSearching,
            isExpanded: $isScoreDataExpanded
        )
    }

    func sessionsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
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

    func resumeCard(_ session: IIDXPlaySession) -> some View {
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

import SwiftUI

struct SessionDetailView: View {
    var store: IIDXSessionStore
    var session: IIDXPlaySession

    @State private var plays: [IIDXCapturedPlay] = []
    @State private var isSummaryExpanded: Bool = true
    @State private var isDJLevelExpanded: Bool = true
    @State private var isClearTypeExpanded: Bool = true
    @State private var isPlaysExpanded: Bool = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20.0) {
                summarySection
                breakdownSection(
                    title: "Sessions.Detail.DJLevelBreakdown",
                    isExpanded: $isDJLevelExpanded,
                    items: djLevelItems
                )
                breakdownSection(
                    title: "Sessions.Detail.ClearTypeBreakdown",
                    isExpanded: $isClearTypeExpanded,
                    items: clearTypeItems
                )
                playsSection
            }
            .padding(.vertical, 8.0)
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
        .navigationTitle("Sessions.Detail.Title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { plays = store.plays(for: session) }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .receive(on: RunLoop.main)) { _ in
            plays = store.plays(for: session)
        }
    }

    private var summarySection: some View {
        VStack(spacing: 12.0) {
            AnalyticsSectionHeader(
                title: "Sessions.Detail.Summary",
                isCollapsible: true,
                isExpanded: isSummaryExpanded
            ) {
                withAnimation(.smooth.speed(2.0)) { isSummaryExpanded.toggle() }
            }
            if isSummaryExpanded {
                VStack(spacing: 0.0) {
                    summaryRow("Shared.Date") {
                        Text(session.startDate, format: .dateTime.year().month().day().hour().minute())
                    }
                    Divider()
                    summaryRow("Sessions.Elapsed") {
                        Text(verbatim: durationText)
                    }
                    Divider()
                    summaryRow("Sessions.Plays") {
                        Text(verbatim: "\(plays.count)")
                    }
                }
            }
        }
    }

    private var playsSection: some View {
        VStack(spacing: 12.0) {
            AnalyticsSectionHeader(
                title: "Sessions.History.Plays",
                isCollapsible: true,
                isExpanded: isPlaysExpanded
            ) {
                withAnimation(.smooth.speed(2.0)) { isPlaysExpanded.toggle() }
            }
            if isPlaysExpanded {
                if plays.isEmpty {
                    Text("Sessions.Empty.Title")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24.0)
                } else {
                    VStack(spacing: 0.0) {
                        ForEach(plays.reversed()) { play in
                            NavigationLink {
                                playDestination(for: play)
                            } label: {
                                CapturedPlayRow(play: play)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Shared.Delete", systemImage: "trash", role: .destructive) {
                                    deletePlay(play)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playDestination(for play: IIDXCapturedPlay) -> some View {
        if play.isFullyConfident {
            CapturedPlayScoreView(store: store, play: play)
        } else {
            CapturedPlayDetailView(store: store, play: play)
        }
    }

    private func deletePlay(_ play: IIDXCapturedPlay) {
        store.deletePlay(play)
        plays = store.plays(for: session)
    }

    @ViewBuilder
    private func breakdownSection(
        title: LocalizedStringKey,
        isExpanded: Binding<Bool>,
        items: [BreakdownItem]
    ) -> some View {
        if !items.isEmpty {
            VStack(spacing: 12.0) {
                AnalyticsSectionHeader(
                    title: title,
                    isCollapsible: true,
                    isExpanded: isExpanded.wrappedValue
                ) {
                    withAnimation(.smooth.speed(2.0)) { isExpanded.wrappedValue.toggle() }
                }
                if isExpanded.wrappedValue {
                    VStack(spacing: 12.0) {
                        breakdownBar(items)
                        breakdownLegend(items)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func breakdownBar(_ items: [BreakdownItem]) -> some View {
        let total = max(1, items.reduce(0) { $0 + $1.count })
        return GeometryReader { proxy in
            HStack(spacing: 0.0) {
                ForEach(items) { item in
                    Rectangle()
                        .fill(item.color)
                        .frame(width: proxy.size.width * CGFloat(item.count) / CGFloat(total))
                }
            }
        }
        .frame(height: 18.0)
        .clipShape(Capsule())
    }

    private func breakdownLegend(_ items: [BreakdownItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96.0), spacing: 8.0)],
            alignment: .leading,
            spacing: 6.0
        ) {
            ForEach(items) { item in
                HStack(spacing: 5.0) {
                    RoundedRectangle(cornerRadius: 2.0)
                        .fill(item.color)
                        .frame(width: 10.0, height: 10.0)
                    Text(verbatim: item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2.0)
                    Text(verbatim: "\(item.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
        }
    }

    private var djLevelItems: [BreakdownItem] {
        IIDXDJLevel.sorted.reversed().compactMap { level in
            let count = plays.filter { $0.djLevel == level.rawValue }.count
            guard count > 0 else { return nil }
            return BreakdownItem(
                label: level.rawValue,
                count: count,
                color: IIDXDJLevel.color(for: level.rawValue)
            )
        }
    }

    private var clearTypeItems: [BreakdownItem] {
        IIDXClearType.sortedWithoutNoPlay.compactMap { clearType in
            let count = plays.filter { $0.clearType == clearType.rawValue }.count
            guard count > 0 else { return nil }
            return BreakdownItem(
                label: IIDXClearType.abbreviation(for: clearType.rawValue),
                count: count,
                color: IIDXClearType.color(for: clearType.rawValue)
            )
        }
    }

    private func summaryRow<Value: View>(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder value: () -> Value
    ) -> some View {
        HStack {
            Text(titleKey)
            Spacer(minLength: 8.0)
            value()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12.0)
    }

    private var durationText: String {
        let minutes = Int(session.duration / 60.0)
        return String(localized: "Sessions.Duration.\(minutes)")
    }
}

private struct BreakdownItem: Identifiable {
    var id: String { label }
    let label: String
    let count: Int
    let color: Color
}

import SwiftUI
import UIKit

struct SessionDetailView: View {
    var store: IIDXSessionStore
    var session: IIDXPlaySession

    @State private var plays: [IIDXCapturedPlay] = []
    @State private var isSummaryExpanded: Bool = true
    @State private var isHeartRateExpanded: Bool = true
    @State private var isDJLevelExpanded: Bool = true
    @State private var isClearTypeExpanded: Bool = true
    @State private var isPlaysExpanded: Bool = true
    @State private var isConfirmingExport: Bool = false
    @State private var fileExport: SessionFileExportRequest?
    @State private var photoAlert: PhotoExportAlert?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20.0) {
                summarySection
                heartRateSection
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
        .navigationTitle(Text(session.startDate, format: .dateTime.year().month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !plays.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sessions.Export.All", systemImage: "square.and.arrow.up.on.square") {
                        isConfirmingExport = true
                    }
                }
            }
        }
        .onAppear { plays = store.plays(for: session) }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .receive(on: RunLoop.main)) { _ in
            plays = store.plays(for: session)
        }
        .confirmationDialog(
            "Sessions.Export.All.Confirm",
            isPresented: $isConfirmingExport,
            titleVisibility: .visible
        ) {
            Button("Sessions.Photos.Save") {
                exportAllToPhotos()
            }
            Button("Sessions.Files.Save") {
                exportAllToFiles()
            }
            Button("Shared.Cancel", role: .cancel) {}
        }
        .sheet(item: $fileExport) { request in
            SessionDocumentExporter(urls: request.urls) {
                fileExport = nil
            }
            .ignoresSafeArea()
        }
        .alert(item: $photoAlert) { alert in
            switch alert {
            case .saved:
                return Alert(title: Text("Sessions.Photos.Saved"), dismissButton: .default(Text("Shared.OK")))
            case .failed:
                return Alert(title: Text("Sessions.Photos.Failed"), dismissButton: .default(Text("Shared.OK")))
            case .denied:
                return Alert(
                    title: Text("Sessions.Photos.Denied.Title"),
                    message: Text("Sessions.Photos.Denied.Message"),
                    dismissButton: .default(Text("Shared.OK"))
                )
            }
        }
    }

    private func exportAllToPhotos() {
        let filenames = plays.map(\.rawImageFilename)
        Task {
            let images: [UIImage] = await Task.detached {
                filenames.compactMap { IIDXSessionImageStore.shared.image(for: $0) }
            }.value
            switch await SessionPhotoExporter.save(images) {
            case .saved: photoAlert = .saved
            case .denied: photoAlert = .denied
            case .failed: photoAlert = .failed
            }
        }
    }

    private func exportAllToFiles() {
        let filenames = plays.map(\.rawImageFilename)
        let urls = SessionFileExporter.exportURLs(for: filenames, date: session.startDate)
        guard !urls.isEmpty else {
            photoAlert = .failed
            return
        }
        fileExport = SessionFileExportRequest(urls: urls)
    }

    private enum PhotoExportAlert: Int, Identifiable {
        case saved, denied, failed
        var id: Int { rawValue }
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
                    if let averageHeartRate {
                        Divider()
                        summaryRow("Sessions.Detail.AverageHeartRate") {
                            Text(verbatim: "\(averageHeartRate)")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var heartRateSection: some View {
        let points = heartRatePoints
        if !points.isEmpty {
            VStack(spacing: 12.0) {
                AnalyticsSectionHeader(
                    title: "Sessions.Detail.HeartRate",
                    isCollapsible: true,
                    isExpanded: isHeartRateExpanded
                ) {
                    withAnimation(.smooth.speed(2.0)) { isHeartRateExpanded.toggle() }
                }
                if isHeartRateExpanded {
                    NavigationLink {
                        SessionHeartRateDetailView(session: session, plays: plays)
                    } label: {
                        SessionHeartRateGraph(session: session, points: points)
                            .padding(.horizontal)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var heartRatePoints: [SessionHeartRatePoint] {
        plays.compactMap { play in
            guard let min = play.minHeartRate, let max = play.maxHeartRate else { return nil }
            return SessionHeartRatePoint(id: play.id, date: play.captureDate, min: min, max: max)
        }
        .sorted { $0.date < $1.date }
    }

    private var averageHeartRate: Int? {
        let points = heartRatePoints
        guard !points.isEmpty else { return nil }
        let total = points.reduce(0.0) { $0 + $1.mid }
        return Int((total / Double(points.count)).rounded())
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

    private func playDestination(for play: IIDXCapturedPlay) -> some View {
        CapturedPlayDestination(store: store, play: play)
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

private struct CapturedPlayDestination: View {
    var store: IIDXSessionStore
    var play: IIDXCapturedPlay

    @State private var showsScore: Bool?

    var body: some View {
        Group {
            if showsScore ?? play.isReviewed {
                CapturedPlayScoreView(store: store, play: play)
            } else {
                CapturedPlayDetailView(store: store, play: play)
            }
        }
        .onAppear {
            if showsScore == nil { showsScore = play.isReviewed }
        }
    }
}

private struct BreakdownItem: Identifiable {
    var id: String { label }
    let label: String
    let count: Int
    let color: Color
}

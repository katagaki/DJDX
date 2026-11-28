import Komponents
import SwiftUI

struct MoreExternalDataSources: View {

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss

    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @State var bemaniWikiEntryCount: Int = 0
    @State var bm2dxEntryCount: Int = 0
    @State var sdvxInEntryCount: Int = 0
    @State var textageEntryCount: Int = 0
    @State var textageChartViewerEntryCount: Int = 0
    @State var ddrSongMetaCount: Int = 0

    @State var reloadingSources: Set<ExternalDataSourceID> = []
    @State var reloadProgress: [ExternalDataSourceID: Double] = [:]
    @State var reloadTasks: [ExternalDataSourceID: Task<Void, Never>] = [:]
    @State var infoSource: ExternalDataSourceID?
    @State var sourcePendingDelete: ExternalDataSourceID?

    let fetcher = IIDXReader()
    let sdvxFetcher = SDVXReader()
    let ddrMetaImporter = DDRMetadataImporter()

    var body: some View {
        Group {
            ScrollView {
                sources()
                    .padding(.horizontal, 16.0)
                    .padding(.vertical, 12.0)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationTitle("More.ExternalData.Header")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
        .alert(
            "More.ExternalData.DeleteData",
            isPresented: Binding(
                get: { sourcePendingDelete != nil },
                set: { if !$0 { sourcePendingDelete = nil } }
            ),
            presenting: sourcePendingDelete
        ) { source in
            Button("Shared.Delete", role: .destructive) {
                sourcePendingDelete = nil
                Task { await deleteData(for: source) }
            }
            Button("Shared.Cancel", role: .cancel) {
                sourcePendingDelete = nil
            }
        } message: { source in
            Text("More.ExternalData.DeleteData.Message.\(siteDisplayName(for: source))")
        }
        .task {
            bemaniWikiEntryCount = await fetcher.bemaniWikiSongCount()
            bm2dxEntryCount = await fetcher.chartRadarDataCount()
            sdvxInEntryCount = await sdvxFetcher.sdvxInChartCount()
            textageEntryCount = await fetcher.textageChartCount()
            textageChartViewerEntryCount = await fetcher.textageChartViewerChartCount()
            ddrSongMetaCount = await ddrMetaImporter.songMetaCount()
        }
    }

    // MARK: - Sources

    @ViewBuilder
    private func sources() -> some View {
        VStack(alignment: .leading, spacing: 10.0) {
            sourceRow(site: "More.ExternalData.TextageChartViewer",
                             detail: Text("More.ExternalData.TextageChartViewer.Description"),
                             footer: "More.ExternalData.TextageChartViewer.Footer",
                             count: textageChartViewerEntryCount,
                             source: .textageChartViewer,
                             url: "https://textage-chart-viewer.vercel.app")
            sourceRow(site: "More.ExternalData.Textage",
                             detail: Text("More.ExternalData.Textage.Description"),
                             footer: "More.ExternalData.Textage.Footer",
                             count: textageEntryCount,
                             source: .textage,
                             url: "https://textage.cc")
            sourceRow(site: "More.ExternalData.SDVXIn",
                             detail: Text("More.ExternalData.SDVXIn.Description"),
                             footer: "More.ExternalData.SDVXIn.Footer",
                             count: sdvxInEntryCount,
                             source: .sdvxIn,
                             url: "https://sdvx.in")
            sourceRow(site: "More.ExternalData.BemaniWiki2nd",
                             detail: Text(verbatim: "beatmania IIDX"),
                             footer: "More.ExternalData.BemaniWiki2nd.Footer",
                             count: bemaniWikiEntryCount,
                             source: .wikiIidx,
                             url: "https://bemaniwiki.com")
            sourceRow(site: "More.ExternalData.BemaniWiki2nd",
                             detail: Text(verbatim: "DanceDanceRevolution"),
                             footer: "More.ExternalData.BemaniWiki2nd.Footer",
                             count: ddrSongMetaCount,
                             source: .wikiDdr,
                             url: "https://bemaniwiki.com")
            sourceRow(site: "More.ExternalData.BM2DX",
                             detail: Text("More.ExternalData.BM2DX.Description"),
                             footer: "More.ExternalData.BM2DX.Footer",
                             count: bm2dxEntryCount,
                             source: .bm2dx,
                             url: "https://bm2dx.com/IIDX/notes_radar/")
            Text("More.ExternalData.Disclaimer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4.0)
        }
    }

    private func sourceRow(
        site: LocalizedStringKey,
        detail: Text,
        footer: LocalizedStringKey,
        count: Int,
        source: ExternalDataSourceID,
        url: String
    ) -> some View {
        let isDownloaded = count > 0
        let isReloading = reloadingSources.contains(source)
        return HStack(spacing: 12.0) {
            VStack(alignment: .leading, spacing: 4.0) {
                Text(site)
                    .font(.playline(size: 12.0))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 6.0) {
                    detail
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if isDownloaded {
                        Text(verbatim: count.formatted())
                            .font(.scoreline(size: 10.0))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 4.0)
            HStack(spacing: 8.0) {
                if isReloading {
                    Button {
                        cancelReload(source)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10.0, weight: .semibold))
                            .frame(width: 22.0, height: 22.0)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .tint(.primary)
                    .overlay {
                        ProgressDonut(progress: reloadProgress[source] ?? 0.0,
                                      lineWidth: 2.5,
                                      tint: .primary,
                                      size: nil)
                            .allowsHitTesting(false)
                    }
                    .accessibilityLabel(Text("Shared.Cancel"))
                } else {
                    Button {
                        startReload(source)
                    } label: {
                        Image(systemName: isDownloaded ? "arrow.clockwise" : "arrow.down")
                            .font(.system(size: 13.0, weight: .semibold))
                            .frame(width: 22.0, height: 22.0)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .tint(.primary)
                    .accessibilityLabel(Text(isDownloaded ? "More.ExternalData.UpdateData" : "More.ExternalData.DownloadData"))
                }
                if isDownloaded {
                    Button(role: .destructive) {
                        sourcePendingDelete = source
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13.0, weight: .semibold))
                            .frame(width: 22.0, height: 22.0)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .disabled(isReloading)
                    .accessibilityLabel(Text("More.ExternalData.DeleteData"))
                }
                Button {
                    infoSource = source
                } label: {
                    Image(systemName: "info")
                        .font(.system(size: 13.0, weight: .semibold))
                        .frame(width: 22.0, height: 22.0)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .tint(.primary)
                .accessibilityLabel(Text("More.ExternalData.Info"))
                .popover(isPresented: Binding(
                    get: { infoSource == source },
                    set: { if !$0, infoSource == source { infoSource = nil } }
                )) {
                    sourceInfoPopover(site: site, footer: footer, url: url)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .padding(.horizontal, 14.0)
        .padding(.vertical, 12.0)
        .cardBackground()
        .environment(\.cardRailColor, isDownloaded ? Color.accentColor : Color.primary.opacity(0.15))
    }

    private func sourceInfoPopover(
        site: LocalizedStringKey,
        footer: LocalizedStringKey,
        url: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10.0) {
            Text(site)
                .font(.playline(size: 13.0))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(footer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let link = URL(string: url) {
                Link(destination: link) {
                    Label("More.ExternalData.ViewSource", systemImage: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(16.0)
        .frame(maxWidth: 280.0, alignment: .leading)
    }

    private func progressHandler(for source: ExternalDataSourceID) -> ExternalDataReloader.Progress {
        { done, total in
            reloadProgress[source] = total > 0 ? Double(done) / Double(total) : 0.0
        }
    }

    private func siteDisplayName(for source: ExternalDataSourceID) -> String {
        switch source {
        case .textageChartViewer:
            String(localized: "More.ExternalData.TextageChartViewer")
        case .textage:
            String(localized: "More.ExternalData.Textage")
        case .sdvxIn:
            String(localized: "More.ExternalData.SDVXIn")
        case .wikiIidx:
            "\(String(localized: "More.ExternalData.BemaniWiki2nd")) (beatmania IIDX)"
        case .wikiDdr:
            "\(String(localized: "More.ExternalData.BemaniWiki2nd")) (DanceDanceRevolution)"
        case .bm2dx:
            String(localized: "More.ExternalData.BM2DX")
        }
    }

    // MARK: - Data Loading

    private func startReload(_ source: ExternalDataSourceID) {
        reloadTasks[source]?.cancel()
        reloadingSources.insert(source)
        reloadProgress[source] = 0.0
        reloadTasks[source] = Task {
            let count = await ExternalDataReloader.reload(
                source, iidxVersion: iidxVersion, progress: progressHandler(for: source)
            )
            guard !Task.isCancelled else { return }
            withAnimation(.smooth.speed(2.0)) {
                setCount(count, for: source)
                reloadingSources.remove(source)
                reloadProgress[source] = nil
                reloadTasks[source] = nil
            }
        }
    }

    private func cancelReload(_ source: ExternalDataSourceID) {
        reloadTasks[source]?.cancel()
        reloadTasks[source] = nil
        withAnimation(.smooth.speed(2.0)) {
            reloadingSources.remove(source)
            reloadProgress[source] = nil
        }
    }

    private func deleteData(for source: ExternalDataSourceID) async {
        await ExternalDataReloader.delete(source)
        withAnimation(.smooth.speed(2.0)) {
            setCount(0, for: source)
        }
    }

    private func setCount(_ count: Int, for source: ExternalDataSourceID) {
        switch source {
        case .textage: textageEntryCount = count
        case .textageChartViewer: textageChartViewerEntryCount = count
        case .sdvxIn: sdvxInEntryCount = count
        case .wikiIidx: bemaniWikiEntryCount = count
        case .bm2dx: bm2dxEntryCount = count
        case .wikiDdr: ddrSongMetaCount = count
        }
    }
}

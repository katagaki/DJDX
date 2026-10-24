import Komponents
import SwiftUI

// swiftlint:disable:next type_body_length
struct MoreExternalDataSources: View {

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss

    @AppStorage(wrappedValue: false, "ExternalData.Textage.Enabled") var isTextageEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.TextageChartViewer.Enabled") var isTextageChartViewerEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.SDVXIn.Enabled") var isSDVXInEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.BemaniWiki2nd.Enabled") var isBemaniWikiEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.BM2DX.Enabled") var isBM2DXEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.DDR.Enabled") var isDDREnabled: Bool
    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @State var bemaniWikiEntryCount: Int = 0
    @State var bm2dxEntryCount: Int = 0
    @State var sdvxInEntryCount: Int = 0
    @State var textageEntryCount: Int = 0
    @State var textageChartViewerEntryCount: Int = 0
    @State var ddrSongMetaCount: Int = 0

    @State var reloadingSources: Set<ExternalDataReloadSource> = []
    @State var reloadProgress: [ExternalDataReloadSource: Double] = [:]

    enum ExternalDataReloadSource {
        case bemaniWiki, bm2dx, sdvxIn, textage, textageChartViewer, ddr
    }

    let fetcher = IIDXReader()
    let sdvxFetcher = SDVXReader()
    let ddrMetaImporter = DDRMetadataImporter()

    var body: some View {
        List {
            textageChartViewerSection()
            textageSection()
            sdvxInSection()
            bemaniWikiSection()
            bm2dxSection()
        }
        .navigationTitle("More.ExternalData.Header")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: [isTextageEnabled, isTextageChartViewerEnabled, isSDVXInEnabled,
                       isBemaniWikiEnabled, isBM2DXEnabled, isDDREnabled]) { _, _ in
            NotificationCenter.default.post(name: .externalDataChanged, object: nil)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if #available(iOS 26.0, *) {
                    Button(role: .close) {
                        dismiss()
                    }
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .tint(.primary)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
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

    // MARK: - Data Source Card

    @ViewBuilder
    private func dataSourceCard<Title: View>(
        @ViewBuilder title: () -> Title,
        count: Int,
        isOn: Binding<Bool>,
        source: ExternalDataReloadSource,
        reload: @escaping () async -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12.0) {
                title()
                    .font(.body)
                Spacer(minLength: 8.0)
                Text(count.formatted())
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Toggle(isOn: isOn) {
                    EmptyView()
                }
                .labelsHidden()
            }
            if isOn.wrappedValue {
                Divider()
                    .padding(.vertical, 12.0)
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSources.insert(source)
                        reloadProgress[source] = 0.0
                        Task {
                            await reload()
                            reloadingSources.remove(source)
                            reloadProgress[source] = nil
                            NotificationCenter.default.post(name: .externalDataChanged, object: nil)
                        }
                    }
                    .disabled(reloadingSources.contains(source))
                    Spacer()
                    reloadIndicator(for: source)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 24.0))
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func reloadIndicator(for source: ExternalDataReloadSource) -> some View {
        if reloadingSources.contains(source) {
            switch source {
            case .bm2dx, .ddr, .textageChartViewer:
                ProgressView()
            default:
                ProgressDonut(progress: reloadProgress[source] ?? 0.0)
            }
        }
    }

    private func progressHandler(for source: ExternalDataReloadSource) -> ExternalDataReloader.Progress {
        { done, total in
            reloadProgress[source] = total > 0 ? Double(done) / Double(total) : 0.0
        }
    }

    // MARK: - BEMANIWiki 2nd

    @ViewBuilder
    private func bemaniWikiSection() -> some View {
        Section {
            dataSourceCard(
                title: { Text(verbatim: "beatmania IIDX") },
                count: bemaniWikiEntryCount,
                isOn: $isBemaniWikiEnabled,
                source: .bemaniWiki,
                reload: reloadBemaniWikiData
            )
            .padding(.bottom, 8.0)
            dataSourceCard(
                title: { Text(verbatim: "DanceDanceRevolution") },
                count: ddrSongMetaCount,
                isOn: $isDDREnabled,
                source: .ddr,
                reload: reloadDDRData
            )
        } header: {
            ListSectionHeader(text: "More.ExternalData.BemaniWiki2nd")
                .font(.body)
        } footer: {
            Text("More.ExternalData.BemaniWiki2nd.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://bemaniwiki.com)")
        }
    }

    // MARK: - bm2dx.com

    @ViewBuilder
    private func bm2dxSection() -> some View {
        Section {
            dataSourceCard(
                title: { Text("More.ExternalData.BM2DX.Description") },
                count: bm2dxEntryCount,
                isOn: $isBM2DXEnabled,
                source: .bm2dx,
                reload: reloadBM2DXData
            )
        } header: {
            ListSectionHeader(text: "More.ExternalData.BM2DX")
                .font(.body)
        } footer: {
            Text("More.ExternalData.BM2DX.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://bm2dx.com/IIDX/notes_radar/)")
        }
    }

    // MARK: - sdvx.in

    @ViewBuilder
    private func sdvxInSection() -> some View {
        Section {
            dataSourceCard(
                title: { Text("More.ExternalData.SDVXIn.Description") },
                count: sdvxInEntryCount,
                isOn: $isSDVXInEnabled,
                source: .sdvxIn,
                reload: reloadSDVXInData
            )
        } header: {
            ListSectionHeader(text: "More.ExternalData.SDVXIn")
                .font(.body)
        } footer: {
            Text("More.ExternalData.SDVXIn.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://sdvx.in)")
        }
    }

    // MARK: - Textage

    @ViewBuilder
    private func textageSection() -> some View {
        Section {
            dataSourceCard(
                title: { Text("More.ExternalData.Textage.Description") },
                count: textageEntryCount,
                isOn: $isTextageEnabled,
                source: .textage,
                reload: reloadTextageData
            )
        } header: {
            ListSectionHeader(text: "More.ExternalData.Textage")
                .font(.body)
        } footer: {
            Text("More.ExternalData.Textage.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://textage.cc)")
        }
    }

    // MARK: - Textage Chart Viewer

    @ViewBuilder
    private func textageChartViewerSection() -> some View {
        Section {
            dataSourceCard(
                title: { Text("More.ExternalData.TextageChartViewer.Description") },
                count: textageChartViewerEntryCount,
                isOn: $isTextageChartViewerEnabled,
                source: .textageChartViewer,
                reload: reloadTextageChartViewerData
            )
        } header: {
            ListSectionHeader(text: "More.ExternalData.TextageChartViewer")
                .font(.body)
        } footer: {
            Text("More.ExternalData.TextageChartViewer.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://textage-chart-viewer.vercel.app)")
        }
    }

    // MARK: - Data Loading

    func reloadTextageData() async {
        textageEntryCount = await ExternalDataReloader.reload(
            .textage, iidxVersion: iidxVersion, progress: progressHandler(for: .textage)
        )
    }

    func reloadTextageChartViewerData() async {
        textageChartViewerEntryCount = await ExternalDataReloader.reload(
            .textageChartViewer, iidxVersion: iidxVersion, progress: progressHandler(for: .textageChartViewer)
        )
    }

    func reloadSDVXInData() async {
        sdvxInEntryCount = await ExternalDataReloader.reload(
            .sdvxIn, iidxVersion: iidxVersion, progress: progressHandler(for: .sdvxIn)
        )
    }

    func reloadBemaniWikiData() async {
        bemaniWikiEntryCount = await ExternalDataReloader.reload(
            .wikiIidx, iidxVersion: iidxVersion, progress: progressHandler(for: .bemaniWiki)
        )
    }

    func reloadBM2DXData() async {
        bm2dxEntryCount = await ExternalDataReloader.reload(
            .bm2dx, iidxVersion: iidxVersion, progress: progressHandler(for: .bm2dx)
        )
    }

    func reloadDDRData() async {
        ddrSongMetaCount = await ExternalDataReloader.reload(
            .wikiDdr, iidxVersion: iidxVersion, progress: progressHandler(for: .ddr)
        )
    }
}

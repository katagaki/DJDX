import Komponents
import SwiftUI

// swiftlint:disable:next type_body_length
struct MoreExternalDataSources: View {

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    
    @AppStorage(wrappedValue: false, "ExternalData.Textage.Enabled") var isTextageEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.SDVXIn.Enabled") var isSDVXInEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.BemaniWiki2nd.Enabled") var isBemaniWikiEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.BM2DX.Enabled") var isBM2DXEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.DDR.Enabled") var isDDREnabled: Bool
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @State var bemaniWikiEntryCount: Int = 0
    @State var bm2dxEntryCount: Int = 0
    @State var sdvxInEntryCount: Int = 0
    @State var textageEntryCount: Int = 0
    @State var ddrSongMetaCount: Int = 0

    @State var isBemaniWikiReloadCompleted: Bool = false
    @State var isBM2DXReloadCompleted: Bool = false
    @State var isSDVXInReloadCompleted: Bool = false
    @State var isTextageReloadCompleted: Bool = false
    @State var isDDRReloadCompleted: Bool = false
    @State var dataImported: Int = 0
    @State var dataTotal: Int = 2
    @State var reloadingSource: ExternalDataReloadSource?

    enum ExternalDataReloadSource {
        case bemaniWiki, bm2dx, sdvxIn, textage, ddr
    }

    let fetcher = IIDXReader()
    let sdvxFetcher = SDVXReader()
    let ddrMetaImporter = DDRMetadataImporter()

    var body: some View {
        List {
            textageSection()
            sdvxInSection()
            bemaniWikiSection()
            bm2dxSection()
        }
        .navigationTitle("More.ExternalData.Header")
        .navigationBarTitleDisplayMode(.inline)
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
            ddrSongMetaCount = await ddrMetaImporter.songMetaCount()
        }
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isBemaniWikiReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isBemaniWikiReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(bemaniWikiEntryCount)")
            }
        )
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isBM2DXReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isBM2DXReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(bm2dxEntryCount)")
            }
        )
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isSDVXInReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isSDVXInReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(sdvxInEntryCount)")
            }
        )
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isTextageReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isTextageReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(textageEntryCount)")
            }
        )
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isDDRReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isDDRReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(ddrSongMetaCount)")
            }
        )
    }

    @ViewBuilder
    private func reloadIndicator(for source: ExternalDataReloadSource) -> some View {
        if reloadingSource == source {
            switch source {
            case .bm2dx, .ddr:
                ProgressView()
            default:
                ProgressDonut(progress: dataTotal > 0 ? Double(dataImported) / Double(dataTotal) : 0.0)
            }
        }
    }

    // MARK: - BEMANIWiki 2nd

    @ViewBuilder
    private func bemaniWikiSection() -> some View {
        Section {
            Toggle(isOn: $isBemaniWikiEnabled) {
                Text(verbatim: "beatmania IIDX")
            }
            if isBemaniWikiEnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .bemaniWiki
                        Task {
                            await reloadBemaniWikiData()
                            reloadingSource = nil
                            isBemaniWikiReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .bemaniWiki)
                }
                HStack {
                    Text("More.ExternalData.BemaniWiki2nd.EntryCount")
                    Spacer()
                    Text(verbatim: "\(bemaniWikiEntryCount)")
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $isDDREnabled) {
                Text(verbatim: "DanceDanceRevolution")
            }
            if isDDREnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .ddr
                        Task {
                            await reloadDDRData()
                            reloadingSource = nil
                            isDDRReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .ddr)
                }
                HStack {
                    Text("More.ExternalData.BemaniWiki2nd.EntryCount")
                    Spacer()
                    Text(verbatim: "\(ddrSongMetaCount)")
                        .foregroundStyle(.secondary)
                }
            }
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
            Toggle(isOn: $isBM2DXEnabled) {
                Text("More.ExternalData.BM2DX.Description")
            }
            if isBM2DXEnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .bm2dx
                        Task {
                            await reloadBM2DXData()
                            reloadingSource = nil
                            isBM2DXReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .bm2dx)
                }
                HStack {
                    Text("More.ExternalData.BM2DX.EntryCount")
                    Spacer()
                    Text(verbatim: "\(bm2dxEntryCount)")
                        .foregroundStyle(.secondary)
                }
            }
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
            Toggle(isOn: $isSDVXInEnabled) {
                Text("More.ExternalData.SDVXIn.Description")
            }
            if isSDVXInEnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .sdvxIn
                        Task {
                            await reloadSDVXInData()
                            reloadingSource = nil
                            isSDVXInReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .sdvxIn)
                }
                HStack {
                    Text("More.ExternalData.SDVXIn.EntryCount")
                    Spacer()
                    Text(verbatim: "\(sdvxInEntryCount)")
                        .foregroundStyle(.secondary)
                }
            }
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
            Toggle(isOn: $isTextageEnabled) {
                Text("More.ExternalData.Textage.Description")
            }
            if isTextageEnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .textage
                        Task {
                            await reloadTextageData()
                            reloadingSource = nil
                            isTextageReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .textage)
                }
                HStack {
                    Text("More.ExternalData.Textage.EntryCount")
                    Spacer()
                    Text(verbatim: "\(textageEntryCount)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            ListSectionHeader(text: "More.ExternalData.Textage")
                .font(.body)
        } footer: {
            Text("More.ExternalData.Textage.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://textage.cc)")
        }
    }

    // MARK: - Textage Data Loading

    func reloadTextageData() async {
        textageEntryCount = await ExternalDataReloader.reload(.textage, iidxVersion: iidxVersion) { done, total in
            dataImported = done
            dataTotal = total
        }
    }

    // MARK: - sdvx.in Data Loading

    func reloadSDVXInData() async {
        sdvxInEntryCount = await ExternalDataReloader.reload(.sdvxIn, iidxVersion: iidxVersion) { done, total in
            dataImported = done
            dataTotal = total
        }
    }

    // MARK: - BEMANIWiki Data Loading

    func reloadBemaniWikiData() async {
        bemaniWikiEntryCount = await ExternalDataReloader.reload(.wikiIidx, iidxVersion: iidxVersion) { done, total in
            dataImported = done
            dataTotal = total
        }
    }

    // MARK: - BM2DX Data Loading

    func reloadBM2DXData() async {
        bm2dxEntryCount = await ExternalDataReloader.reload(.bm2dx, iidxVersion: iidxVersion) { done, total in
            dataImported = done
            dataTotal = total
        }
    }

    func reloadDDRData() async {
        ddrSongMetaCount = await ExternalDataReloader.reload(.wikiDdr, iidxVersion: iidxVersion) { done, total in
            dataImported = done
            dataTotal = total
        }
    }
}
